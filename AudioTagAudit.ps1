param (
    [Parameter(Mandatory = $true)]
    [string]$RootFolderPath,

    [string]$OutputCsvPath = ".\AudioTagAudit.csv",

    [switch]$AlbumsOnly
)

# Load TagLib# (silently)
try {
    Add-Type -Path "D:\dev\projects\taglib-sharp\src\TaglibSharp\bin\Release\net6.0\TagLibSharp.dll" -ErrorAction Stop | Out-Null
} catch {
    $taglibUrl = "https://github.com/mono/taglib-sharp/releases/download/2.3.0/TagLibSharp.dll"
    $dllPath = "$env:TEMP\TagLibSharp.dll"
    Invoke-WebRequest $taglibUrl -OutFile $dllPath -ErrorAction Stop
    Add-Type -Path $dllPath -ErrorAction Stop | Out-Null
}

# Validate path
if (-not (Test-Path $RootFolderPath)) {
    Write-Error "Folder not found: $RootFolderPath" -ErrorAction Stop
    exit 1
}

# Supported audio formats
$audioExtensions = "*.mp3", "*.flac", "*.m4a", "*.ogg", "*.wma"

# Results storage
$auditResults = @()
$albumIssues = @{}

# Scan files recursively
$audioFiles = Get-ChildItem -Path $RootFolderPath -Recurse -File -Include $audioExtensions

foreach ($file in $audioFiles) {
    try {
        $tfile = [TagLib.File]::Create($file.FullName)
        $tag = $tfile.Tag

        $issues = @()

        # Check metadata fields
        if ([string]::IsNullOrWhiteSpace($tag.Album))        { $issues += "Missing Album" }
        if ($tag.AlbumArtists.Count -eq 0)                  { $issues += "Missing AlbumArtist" }
        if ([string]::IsNullOrWhiteSpace($tag.Title))        { $issues += "Missing Title" }
        if ($tag.Track -eq 0)                                { $issues += "Missing Track" }
        if ($tag.Disc -eq 0)                                 { $issues += "Missing DiscNumber" }
        if ($tag.Genres.Count -eq 0)                         { $issues += "Missing Genre" }
        if ($tag.Year -eq 0)                                 { $issues += "Missing Year" }

        # Check cover art
        if ($tfile.Tag.Pictures.Count -eq 0) {
            $issues += "Missing Cover Art"
        } else {
            try {
                $pic = $tfile.Tag.Pictures[0]
                $img = [System.Drawing.Image]::FromStream([System.IO.MemoryStream]::new($pic.Data.Data))
                if ($img.Width -lt 300 -or $img.Height -lt 300) {
                    $issues += "Cover too small"
                }
                $img.Dispose()
            } catch {
                $issues += "Invalid Cover Image"
            }
        }

        # Group by album (if AlbumsOnly)
        if ($AlbumsOnly) {
            $albumKey = "$($tag.AlbumArtists[0]) - $($tag.Album)"
            if (-not $albumIssues.ContainsKey($albumKey)) {
                $albumIssues[$albumKey] = [System.Collections.Generic.HashSet[string]]::new()
            }
            foreach ($issue in $issues) {
                $null = $albumIssues[$albumKey].Add($issue)  # Suppress output
            }
        } else {
            $auditResults += [pscustomobject]@{
                File        = $file.FullName
                Album       = $tag.Album
                AlbumArtist = if ($tag.AlbumArtists.Count -gt 0) { $tag.AlbumArtists[0] } else { "" }
                Title       = $tag.Title
                Track       = $tag.Track
                DiscNumber  = $tag.Disc
                Genre       = if ($tag.Genres.Count -gt 0) { $tag.Genres[0] } else { "" }
                Year        = $tag.Year
                Issues      = if ($issues.Count -gt 0) { $issues -join "; " } else { "None" }
            }
        }
    } catch {
        $auditResults += [pscustomobject]@{
            File        = $file.FullName
            Album       = "ERROR"
            AlbumArtist = "ERROR"
            Title       = "ERROR"
            Track       = "ERROR"
            DiscNumber  = "ERROR"
            Genre       = "ERROR"
            Year        = "ERROR"
            Issues      = "Failed to read metadata: $_"
        }
    }
}

# Generate sorted CSV output
if ($AlbumsOnly) {
    $albumResults = @()
    
    # Count issue frequency
    $issueFrequency = @{}
    foreach ($issues in $albumIssues.Values) {
        foreach ($issue in $issues) {
            if (-not $issueFrequency.ContainsKey($issue)) {
                $issueFrequency[$issue] = 0
            }
            $issueFrequency[$issue]++
        }
    }
    
    # Sort issues by frequency (descending)
    $sortedIssues = $issueFrequency.GetEnumerator() | Sort-Object Value -Descending | Select-Object -ExpandProperty Name
    
    # Build album results with sorted issues
    foreach ($album in $albumIssues.Keys) {
        $sortedAlbumIssues = $albumIssues[$album] | Sort-Object {
            $issueRank = [array]::IndexOf($sortedIssues, $_)
            if ($issueRank -eq -1) { [int]::MaxValue } else { $issueRank }
        }
        $albumResults += [pscustomobject]@{
            Album  = $album
            Issues = $sortedAlbumIssues -join "; "
        }
    }
    
    $albumResults | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
} else {
    $auditResults | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
}

Write-Host "Audit complete. Report saved to: $OutputCsvPath" -ForegroundColor Cyan