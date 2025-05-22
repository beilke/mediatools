# Configuration
$sourceRoot = "Y:\-- MP3 HQ\VA\The Definitive Horror Music Collection (2009) [320]"
$destinationRoot = "Y:\-- MP3 HQ\VA\The Definitive Horror Music Collection (Renamed)"

# Create destination directory if it doesn't exist
if (!(Test-Path $destinationRoot)) {
    New-Item -ItemType Directory -Path $destinationRoot | Out-Null
}

# Define the complete tracklist
$tracklist = @(
    # CD 1
    @{CD=1; Track=1; Movie="Drag Me to Hell"; Title="End Titles (Original Version)"; Artist="Christopher Young"},
    @{CD=1; Track=2; Movie="Twilight"; Title="Edward at Her Bed (Bella's Lullaby)"; Artist="Carter Burwell"},
    # ... [rest of your tracklist] ...
    @{CD=4; Track=15; Movie="Nosferatu"; Title="Overture"; Artist="Hans Erdmann"}
)

# Process each CD
foreach ($cd in 1..4) {
    $sourceDir = Join-Path $sourceRoot "CD $cd"
    $destDir = Join-Path $destinationRoot "CD $cd"
    
    # Create destination CD directory
    if (!(Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir | Out-Null
    }

    # Get all files in source directory sorted by name
    $sourceFiles = Get-ChildItem $sourceDir | Sort-Object Name
    
    # Get tracks for current CD
    $cdTracks = $tracklist | Where-Object { $_.CD -eq $cd }
    
    # Match files to tracks by position (since we have them in order)
    for ($i = 0; $i -lt $cdTracks.Count; $i++) {
        $track = $cdTracks[$i]
        $sourceFile = $sourceFiles[$i]
        
        if ($sourceFile -and $track) {
            # Create new filename
            $newName = "{0}{1:00} - {2} + {3} - {4}.mp3" -f 
                $track.CD,
                $track.Track,
                $track.Movie,
                $track.Title,
                $track.Artist
            
            # Clean filename of invalid characters
            $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
            foreach ($char in $invalidChars) {
                $newName = $newName.Replace($char, '_')
            }
            
            $destFile = Join-Path $destDir $newName
            
            # Copy the file
            Copy-Item -Path $sourceFile.FullName -Destination $destFile -Force
            Write-Host "Copied [$($track.CD)$($track.Track)]: $($sourceFile.Name) -> $newName"
        } else {
            Write-Warning "Could not process track $($track.Track) in CD $cd - file may be missing"
        }
    }
}

Write-Host "`nAll files copied to: $destinationRoot" -ForegroundColor Green