# PowerShell script to check for Atmos (TrueHD Atmos or E-AC3 Atmos) in MKV and MP4 files (including subfolders)
Write-Output "Checking for files with Dolby Atmos (TrueHD Atmos or E-AC3 Atmos) in all subfolders..."

# Get all MKV and MP4 files in the current directory and subdirectories
$files = Get-ChildItem -Path . -Recurse -Include *.mkv, *.mp4

foreach ($file in $files) {
    # Run FFmpeg and capture the output
    $ffmpegOutput = ffmpeg -i "$($file.FullName)" 2>&1

    # Check if the output contains TrueHD with Atmos metadata
    if ($ffmpegOutput -match "Audio: truehd" -and $ffmpegOutput -match "Atmos") {
        Write-Output "$($file.FullName) contains TrueHD Atmos"
    }
    # Check if the output contains E-AC3 Atmos (Dolby Digital Plus Atmos)
    elseif ($ffmpegOutput -match "Audio: eac3" -and ($ffmpegOutput -match "JOC" -or $ffmpegOutput -match "Dolby Atmos")) {
        Write-Output "$($file.FullName) contains E-AC3 Atmos"
    }
}