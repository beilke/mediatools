$inputPath = "U:\docker\complete\ultrahd23\BDMV\STREAM"
$outputDir = "U:\docker\complete"

Get-ChildItem -Path $inputPath -Recurse -File | ForEach-Object {
    $outputName = "{0}_{1}.mkv" -f $_.Directory.Parent.Name, $_.BaseName
    $outputPath = Join-Path -Path $outputDir -ChildPath $outputName

    if (-not (Test-Path -Path $outputPath)) {
        & "C:\Program Files\HandBrake\HandBrakeCLI.exe" -i $_.FullName -o $outputPath `
            --format av_mkv `
            --encoder nvenc_h265 `
            --quality 22 `
            --vfr `
            --audio-lang-list all `
            --all-audio `
            --aencoder copy `
            --audio-copy-mask dts,dtshd,ac3,eac3,truehd,aac,mp3,flac `
            --audio-fallback none `
            --subtitle-lang-list all `
            --all-subtitles
    }
    else {
        Write-Warning "Skipped (already exists): $outputPath"
    }
}