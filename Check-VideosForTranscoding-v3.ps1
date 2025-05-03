# Configuration
$LibraryPath = "."  # Change to your media library path
$ProcessedFilesPath = "processed_files.txt"
$OutputLog = "transcoding_needed.log"
$MaxParallelJobs = 4  # Adjust based on CPU (4-8 recommended)

# Load processed files (using MD5 hashes for change detection)
$ProcessedFiles = @{}
if (Test-Path $ProcessedFilesPath) {
    Get-Content $ProcessedFilesPath | ForEach-Object { 
        $Parts = $_ -split "::"
        if ($Parts.Length -eq 2) { $ProcessedFiles[$Parts[0]] = $Parts[1] }
    }
}

# Get video files
$VideoFiles = Get-ChildItem -Path $LibraryPath -Recurse -File -Include *.mkv,*.mp4,*.avi,*.mov
$TotalFiles = $VideoFiles.Count
$CompletedFiles = 0

# Initialize progress tracking
$ProgressParams = @{
    Activity = "Scanning Video Files"
    Status = "Initializing..."
    PercentComplete = 0
}

# Process files in parallel
$Jobs = @()
foreach ($File in $VideoFiles) {
    # Skip already processed (unchanged) files
    $FileHash = (Get-FileHash -Path $File.FullName -Algorithm MD5).Hash
    if ($ProcessedFiles.ContainsKey($File.FullName) -and $ProcessedFiles[$File.FullName] -eq $FileHash) {
        $CompletedFiles++
        continue
    }

    # Start parallel job
    $Jobs += Start-Job -ScriptBlock {
        param($FilePath, $ProcessedFilesPath, $OutputLog)

        # Helper function for FFprobe queries
        function Get-MediaProperty($FilePath, $Property) {
            $result = (ffprobe -v error -select_streams v:0 -show_entries stream=$Property -of csv=p=0 "$FilePath" 2>$null).Trim()
            return if ([string]::IsNullOrEmpty($result)) { "N/A" } else { $result }
        }

        # Main media analysis function
        function Get-MediaInfo($FilePath) {
            # Basic video properties
            $Codec = Get-MediaProperty $FilePath "codec_name"
            $BitDepth = Get-MediaProperty $FilePath "bits_per_raw_sample"
            $PixelFormat = Get-MediaProperty $FilePath "pix_fmt"
            $Level = if ($Codec -eq "h264") { Get-MediaProperty $FilePath "level" } else { "N/A" }

            # Fallback bit depth detection
            if ($BitDepth -eq "N/A" -or $BitDepth -eq "Unknown") {
                if ($PixelFormat -match "yuv420p10le") { $BitDepth = "10" }
                elseif ($PixelFormat -match "yuv420p") { $BitDepth = "8" }
            }

            # Dolby Vision detection
            $DVProfile = "N/A"
            $DVJson = ffprobe -v error -select_streams v:0 -show_entries stream=side_data_list -of json "$FilePath" 2>$null | ConvertFrom-Json
            if ($DVJson.side_data_list) {
                $DVProfile = $DVJson.side_data_list | Where-Object { $_.dolby_vision_profile } | 
                            Select-Object -ExpandProperty dolby_vision_profile -ErrorAction SilentlyContinue
                $DVProfile = if ($DVProfile) { $DVProfile.ToString() } else { "N/A" }
            }

            return @{
                Codec = $Codec
                BitDepth = $BitDepth
                Chroma = $PixelFormat
                Level = $Level
                DVProfile = $DVProfile
            }
        }

        # Compatibility check function
        function Needs-Transcoding($MediaInfo) {
            $SupportedCodecs = @("h264", "hevc", "mpeg4", "mpeg2video", "vp9")

            # Unsupported codec
            if ($SupportedCodecs -notcontains $MediaInfo.Codec) { return $true }

            # 10-bit H.264
            if ($MediaInfo.Codec -eq "h264" -and $MediaInfo.BitDepth -eq "10") { return $true }

            # High H.264 level (>5.2)
            if ($MediaInfo.Codec -eq "h264" -and $MediaInfo.Level -ne "N/A") {
                $HighLevels = @("5.3", "6.0", "6.1", "6.2")
                if ($HighLevels -contains $MediaInfo.Level) { return $true }
            }

            # 4:2:2 chroma subsampling
            if ($MediaInfo.Chroma -match "422") { return $true }

            # Incompatible Dolby Vision
            $BadDVProfiles = @("4", "5", "7")
            if ($BadDVProfiles -contains $MediaInfo.DVProfile) { return $true }

            return $false
        }

        # Get media info and check compatibility
        $MediaInfo = Get-MediaInfo $FilePath
        if ($MediaInfo -eq $null) { return }

        if (Needs-Transcoding $MediaInfo) {
            $Message = "Unsupported: Codec=$($MediaInfo.Codec), BitDepth=$($MediaInfo.BitDepth), " +
                       "Chroma=$($MediaInfo.Chroma), Level=$($MediaInfo.Level), " +
                       "DVProfile=$($MediaInfo.DVProfile) -> $FilePath"
            Write-Output $Message
            Add-Content -Path $OutputLog -Value $Message
        }

        # Update processed files cache
        $FileHash = (Get-FileHash -Path $FilePath -Algorithm MD5).Hash
        "$FilePath::$FileHash" | Out-File -Append -FilePath $ProcessedFilesPath
    } -ArgumentList $File.FullName, $ProcessedFilesPath, $OutputLog

    # Throttle jobs
    while ((Get-Job -State Running).Count -ge $MaxParallelJobs) {
        Start-Sleep -Milliseconds 500
        # Update progress
        $Completed = $CompletedFiles + @(Get-Job -State Completed).Count
        $ProgressParams.PercentComplete = ($Completed / $TotalFiles) * 100
        $ProgressParams.Status = "Processed $Completed of $TotalFiles files"
        Write-Progress @ProgressParams
    }
}

# Final cleanup and progress
Write-Progress -Activity "Finalizing" -Status "Waiting for remaining jobs..." -PercentComplete 90
$Jobs | Wait-Job | Out-Null

# Collect results
$Jobs | ForEach-Object {
    Receive-Job -Job $_
    Remove-Job -Job $_
}

Write-Progress -Activity "Complete" -Completed
Write-Host "Scan completed. Results logged to $OutputLog"