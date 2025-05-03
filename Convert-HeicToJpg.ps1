<#
.SYNOPSIS
    Converts HEIC files to JPG recursively while preserving metadata.
.DESCRIPTION
    This script converts all HEIC files in the specified directory (and subdirectories) to JPG format,
    maintains EXIF metadata and quality, moves originals to a backup folder, and handles duplicates.
    Uses modern ImageMagick 7+ syntax.
.PARAMETER TargetDirectory
    The directory to search for HEIC files.
.PARAMETER BackupDirectory
    (Optional) Where to move original HEIC files. Defaults to "[TargetDirectory]\heic_backup".
.PARAMETER Quality
    (Optional) JPG quality (1-100). Defaults to 95.
.EXAMPLE
    .\Convert-HeicToJpg.ps1 -TargetDirectory "C:\Photos"
.EXAMPLE
    .\Convert-HeicToJpg.ps1 -TargetDirectory "C:\Photos" -BackupDirectory "C:\Backups" -Quality 100
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$TargetDirectory,

    [string]$BackupDirectory,

    [ValidateRange(1,100)]
    [int]$Quality = 95
)

# Check if ImageMagick is available
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Error "ImageMagick (magick) is not installed or not in PATH. Please install it first."
    exit 1
}

# Set default backup directory if not specified
if (-not $BackupDirectory) {
    $BackupDirectory = Join-Path -Path $TargetDirectory -ChildPath "heic_backup"
}

# Create backup directory if it doesn't exist
if (-not (Test-Path -Path $BackupDirectory)) {
    New-Item -ItemType Directory -Path $BackupDirectory | Out-Null
}

# Get all HEIC files recursively (including .HEIC extension)
$heicFiles = Get-ChildItem -Path $TargetDirectory -Include "*.heic","*.HEIC" -Recurse -File

if ($heicFiles.Count -eq 0) {
    Write-Host "No HEIC files found in $TargetDirectory"
    exit 0
}

Write-Host "Found $($heicFiles.Count) HEIC files to process..."
Write-Host "Using JPG quality: $Quality"
Write-Host "Backup location: $BackupDirectory`n"

$processedCount = 0
$skippedCount = 0
$failedCount = 0

foreach ($heicFile in $heicFiles) {
    # Determine output JPG path (same directory with .jpg extension)
    $jpgPath = [System.IO.Path]::ChangeExtension($heicFile.FullName, ".jpg")
    
    # Skip if JPG already exists and is newer than HEIC
    if (Test-Path -Path $jpgPath) {
        $jpgFile = Get-Item -Path $jpgPath
        if ($jpgFile.LastWriteTime -ge $heicFile.LastWriteTime) {
            Write-Host "Skipping (JPG already exists and is newer): $($heicFile.FullName)" -ForegroundColor Yellow
            $skippedCount++
            continue
        }
        
        # Append random number if we're going to overwrite
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($heicFile.Name)
        $random = Get-Random -Minimum 1000 -Maximum 9999
        $newName = "${baseName}_${random}.jpg"
        $jpgPath = Join-Path -Path $heicFile.DirectoryName -ChildPath $newName
    }

    # Determine backup path (maintain relative structure)
    $relativePath = [System.IO.Path]::GetRelativePath($TargetDirectory, $heicFile.DirectoryName)
    $backupPath = Join-Path -Path $BackupDirectory -ChildPath $relativePath
    
    # Create subdirectory in backup location if needed
    if (-not (Test-Path -Path $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    }
    
    $backupFile = Join-Path -Path $backupPath -ChildPath $heicFile.Name
    
    # If backup file exists, append random number
    if (Test-Path -Path $backupFile) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($heicFile.Name)
        $random = Get-Random -Minimum 1000 -Maximum 9999
        $newName = "${baseName}_${random}.heic"
        $backupFile = Join-Path -Path $backupPath -ChildPath $newName
    }

    Write-Host "Processing: $($heicFile.FullName)"
    Write-Host "Converting to: $jpgPath"
    Write-Host "Backup original to: $backupFile"
    
    try {
        # Convert HEIC to JPG using modern ImageMagick 7+ syntax
        & magick "$($heicFile.FullName)" -quality $Quality -define jpeg:preserve-settings "$jpgPath"
        
        if ($LASTEXITCODE -ne 0) {
            throw "ImageMagick conversion failed with exit code $LASTEXITCODE"
        }
        
        # Verify JPG was created
        if (-not (Test-Path -Path $jpgPath)) {
            throw "JPG file was not created"
        }
        
        # Preserve original file timestamps
        $jpgItem = Get-Item -Path $jpgPath
        $jpgItem.CreationTime = $heicFile.CreationTime
        $jpgItem.LastWriteTime = $heicFile.LastWriteTime
        $jpgItem.LastAccessTime = $heicFile.LastAccessTime
        
        # Move original to backup location
        Move-Item -Path $heicFile.FullName -Destination $backupFile -Force
        
        $processedCount++
        Write-Host "Successfully processed $($heicFile.Name)`n" -ForegroundColor Green
    }
    catch {
        $failedCount++
        Write-Error "Failed to process $($heicFile.Name): $_"
    }
}

Write-Host "`nConversion summary:"
Write-Host "Processed: $processedCount files" -ForegroundColor Green
Write-Host "Skipped: $skippedCount files (already converted)" -ForegroundColor Yellow
Write-Host "Failed: $failedCount files" -ForegroundColor Red
if ($failedCount -gt 0) {
    Write-Host "Check error messages above for failed conversions"
}