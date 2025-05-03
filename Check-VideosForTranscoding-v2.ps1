#$LibraryPath = "W:\movies"  # Change to your media library path
$ProcessedFilesPath = "processed_files.txt"
$MaxParallelJobs = 4  # Adjust based on CPU (4-8 recommended)

# Load processed files into a hashtable for fast lookup
$ProcessedFiles = @{}
if (Test-Path $ProcessedFilesPath) {
    Get-Content $ProcessedFilesPath | ForEach-Object { $ProcessedFiles[$_] = $true }
}

# Get list of video files
$VideoFiles = Get-ChildItem -Path . -Recurse -File -Include *.mkv, *.mp4, *.avi, *.mov

# Use parallel jobs to speed up processing
$Jobs = @()
foreach ($File in $VideoFiles) {
    if ($ProcessedFiles.ContainsKey($File.FullName)) { continue }  # Skip already processed files

    $Jobs += Start-Job -ScriptBlock {
        param($FilePath, $ProcessedFilesPath)

        # Function must be defined inside the job!
        function Get-MediaInfo($FilePath) {
            $ffprobeOutput = & ffprobe -v error -select_streams v:0 `
                -show_entries stream=codec_name,pix_fmt,bits_per_raw_sample `
                -of csv=p=0 "$FilePath"

            $ffprobeLines = $ffprobeOutput -split "`n"
            if ($ffprobeLines.Count -lt 2) { return $null }

            $Codec = $ffprobeLines[0].Trim()
            $PixelFormat = $ffprobeLines[1].Trim()
            $BitDepth = if ($ffprobeLines.Count -gt 2) { $ffprobeLines[2].Trim() } else { "Unknown" }

            # Convert pixel format to bit depth if needed
            if ($BitDepth -eq "N/A" -or $BitDepth -eq "Unknown") {
                if ($PixelFormat -match "yuv420p10le") { $BitDepth = "10" }
                elseif ($PixelFormat -match "yuv420p") { $BitDepth = "8" }
            }

            return @{ Codec = $Codec; BitDepth = $BitDepth; Chroma = $PixelFormat }
        }

        function Needs-Transcoding($Codec, $BitDepth, $Chroma) {
            $SupportedCodecs = @("h264", "hevc", "mpeg4", "mpeg2video", "vp9")

            if ($SupportedCodecs -notcontains $Codec) { return $true }
            if ($Codec -eq "h264" -and $BitDepth -eq "10") { return $true }
            if ($Chroma -match "422") { return $true }  # 4:2:2 chroma is unsupported
            return $false
        }

        # Load ffprobe data
        $MediaInfo = Get-MediaInfo $FilePath
        if ($MediaInfo -eq $null) { return }

        # Check if transcoding is needed
        $NeedsTranscoding = Needs-Transcoding $MediaInfo.Codec $MediaInfo.BitDepth $MediaInfo.Chroma
        if ($NeedsTranscoding) {
            $Message = "Unsupported format: Codec=$($MediaInfo.Codec), BitDepth=$($MediaInfo.BitDepth), Chroma=$($MediaInfo.Chroma) -> $FilePath"
            Write-Output $Message
            Add-Content -Path "unsupported_files.log" -Value $Message
        }

        # Mark as processed immediately
        Add-Content -Path $ProcessedFilesPath -Value $FilePath
    } -ArgumentList $File.FullName, $ProcessedFilesPath

    # Limit concurrent jobs
    while (@(Get-Job -State Running).Count -ge $MaxParallelJobs) {
        Start-Sleep -Seconds 1
    }
}

# Wait for all jobs to finish
$Jobs | ForEach-Object { Receive-Job -Job $_; Remove-Job -Job $_ }
