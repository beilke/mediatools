$videoTsPath = "D:\temp\VIDEO_TS"
$dvdFolder = Split-Path $videoTsPath -Parent
$baseName = Split-Path $dvdFolder -Leaf
$handbrake = "C:\Program Files\HandBrake\HandBrakeCLI.exe"

# Run scan to get all titles
$titlesOutput = & $handbrake -i $videoTsPath -t 0 2>&1

# Parse output for lines like "+ title 1:"
$titleNumbers = @()
foreach ($line in $titlesOutput) {
    if ($line -match "^\s*\+\s+title\s+(\d+):") {
        $titleNumbers += [int]$matches[1]
    }
}

if ($titleNumbers.Count -eq 0) {
    Write-Host "⚠️  No titles found in VIDEO_TS. Check if the DVD is valid."
    return
}

# Process each title
foreach ($title in $titleNumbers) {
    $outputFile = "D:\${baseName}_Title$('{0:D2}' -f $title).mkv"
    Write-Host "🎬 Encoding Title $title to $outputFile..."

    & $handbrake -i $videoTsPath -o $outputFile `
        -t $title `
        --format av_mkv `
        --encoder nvenc_h265 `
        --quality 22 `
        --vfr `
        --markers `
        --audio-lang-list all `
        --all-audio `
        --aencoder copy `
        --audio-copy-mask dts,dtshd,ac3,eac3,truehd,aac,mp3,flac `
        --audio-fallback none `
        --subtitle-lang-list all `
        --all-subtitles
}
