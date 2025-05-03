# Define the directory to scan (Change this to your library path)
#$VideoDir = "C:\path\to\your\library"

# Output file for videos needing transcoding
$OutputFile = "transcoding_needed.txt"

# File to store already processed videos
$CacheFile = "processed_files.txt"

# Load processed files into a hashtable
$ProcessedFiles = @{}
if (Test-Path $CacheFile) {
    Get-Content $CacheFile | ForEach-Object { 
        $Parts = $_ -split "::"
        if ($Parts.Length -eq 2) {
            $ProcessedFiles[$Parts[0]] = $Parts[1]
        }
    }
}

# Function to check if a codec is supported
function Is-SupportedCodec {
    param ($Codec, $BitDepth, $ChromaSubsampling)
    $SupportedCodecs = @("h264", "hevc", "vp9", "mpeg2video", "mpeg4")

    # Check if codec is in the supported list
    if (-not ($SupportedCodecs -contains $Codec)) {
        return $false
    }

    # H.264/AVC is only supported in 8-bit, not 10-bit
    if ($Codec -eq "h264" -and $BitDepth -eq "10") {
        return $false
    }

    # Any format using 4:2:2 chroma subsampling is incompatible
    if ($ChromaSubsampling -eq "4:2:2") {
        return $false
    }

    return $true
}

# Function to check if H.264 level is higher than 5.2
function Is-H264LevelTooHigh {
    param ($Level)
    $HighLevels = @("5.3", "6.0", "6.1", "6.2")
    return $HighLevels -contains $Level
}

# Function to check for incompatible Dolby Vision profiles
function Is-IncompatibleDolbyVision {
    param ($DVProfile)
    $IncompatibleProfiles = @("4", "5", "7")
    return $IncompatibleProfiles -contains $DVProfile
}

# Scan video files
$VideoFiles = Get-ChildItem -Path . -Recurse -Include *.mkv, *.mp4, *.avi, *.mov, *.wmv, *.flv
$TotalFiles = $VideoFiles.Count
$CurrentFileIndex = 0

foreach ($File in $VideoFiles) {
    $CurrentFileIndex++
    $ProgressPercent = ($CurrentFileIndex / $TotalFiles) * 100
    Write-Progress -Activity "Scanning Video Files" -Status "Processing: $($File.Name)" -PercentComplete $ProgressPercent

    # Check if the file was already processed
    $FileHash = Get-FileHash -Path $File.FullName -Algorithm MD5 | Select-Object -ExpandProperty Hash
    if ($ProcessedFiles.ContainsKey($File.FullName) -and $ProcessedFiles[$File.FullName] -eq $FileHash) {
        continue  # Skip already processed files
    }

    # Get video codec, bit depth, and chroma subsampling
    #$Codec = ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$($File.FullName)" 2>$null
    $Codec = (ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$($File.FullName)" 2>$null).Trim()

    #$BitDepth = ffprobe -v error -select_streams v:0 -show_entries stream=bits_per_raw_sample -of csv=p=0 "$($File.FullName)" 2>$null
    $BitDepth = ffprobe -v error -select_streams v:0 -show_entries stream=bits_per_raw_sample -of csv=p=0 "$($File.FullName)" 2>$null

# Fallback method if bit depth is missing
if (-not $BitDepth -or $BitDepth -eq "N/A") {
    $BitDepth = ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "$($File.FullName)" 2>$null
    if ($BitDepth -match "yuv420p10le") {
        $BitDepth = "10"
    } elseif ($BitDepth -match "yuv420p") {
        $BitDepth = "8"
    } else {
        $BitDepth = "Unknown"
    }
}

    $ChromaSubsampling = ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "$($File.FullName)" 2>$null

    # Check if H.264 level is too high
    if ($Codec -eq "h264") {
        $Level = ffprobe -v error -select_streams v:0 -show_entries stream=level -of csv=p=0 "$($File.FullName)" 2>$null
        if (Is-H264LevelTooHigh $Level) {
            $Message = "H.264 Level $Level too high -> $($File.FullName)"
            Write-Host $Message
            Add-Content -Path $OutputFile -Value $Message
        }
    }

    # Check for unsupported codecs, 10-bit H.264, or 4:2:2 chroma
    #if (-not (Is-SupportedCodec $Codec $BitDepth $ChromaSubsampling)) {
    if (-not (Is-SupportedCodec $Codec $BitDepth $ChromaSubsampling) -and -not ($Codec -eq "hevc" -and $ChromaSubsampling -match "yuv420p10le")) {
        #$Message = "Unsupported format ($Codec, BitDepth: $BitDepth, Chroma: $ChromaSubsampling) -> $($File.FullName)"
        $Message = "Unsupported format: Codec=$Codec, BitDepth=$BitDepth, Chroma=$ChromaSubsampling -> $($File.FullName)"

        Write-Host $Message
        Add-Content -Path $OutputFile -Value $Message
    }

    # Check for Dolby Vision incompatibility
    $DVProfileJson = ffprobe -v error -select_streams v:0 -show_entries stream=side_data_list -of json "$($File.FullName)" 2>$null | ConvertFrom-Json
    if ($DVProfileJson.side_data_list) {
        $DVProfile = $DVProfileJson.side_data_list | Where-Object { $_."dolby_vision_profile" } | Select-Object -ExpandProperty "dolby_vision_profile" -ErrorAction SilentlyContinue
        if ($DVProfile -and (Is-IncompatibleDolbyVision $DVProfile)) {
            $Message = "Incompatible Dolby Vision Profile ($DVProfile) -> $($File.FullName)"
            Write-Host $Message
            Add-Content -Path $OutputFile -Value $Message
        }
    }

    # Write file hash to cache immediately after processing
    "$($File.FullName)::$FileHash" | Out-File -Append -FilePath $CacheFile
}

Write-Progress -Activity "Scanning Complete" -Completed
Write-Host "Check completed. Files needing transcoding are listed in $OutputFile."
