# Replace underscores with hyphens in title tag for all audio files in a folder

param (
    [Parameter(Mandatory = $true)]
    [string]$RootFolderPath
)

# Check if folder exists
if (-Not (Test-Path $RootFolderPath)) {
    Write-Error "Folder not found: $RootFolderPath"
    exit
}

# Load TagLib#
Add-Type -Path "D:\dev\projects\taglib-sharp\src\TaglibSharp\bin\Release\net6.0\TagLibSharp.dll" -ErrorAction SilentlyContinue

# If TagLibSharp is not found, download it temporarily
if (-not ("TagLib.File" -as [type])) {
    $taglibUrl = "https://github.com/mono/taglib-sharp/releases/download/2.3.0/TagLibSharp.dll"
    $dllPath = "$env:TEMP\TagLibSharp.dll"
    Invoke-WebRequest $taglibUrl -OutFile $dllPath
    Add-Type -Path $dllPath
}

# Get all supported audio files
$audioExtensions = @("*.mp3", "*.flac", "*.m4a", "*.ogg", "*.wma")
$files = Get-ChildItem -Path $RootFolderPath -Recurse -Include $audioExtensions

foreach ($file in $files) {
    try {
        $tfile = [TagLib.File]::Create($file.FullName)
        
        # Only process if title exists
        if ($tfile.Tag.Title) {
            $originalTitle = $tfile.Tag.Title
            $newTitle = $originalTitle -replace '_', '-'
            
            # Only update if there was a change
            if ($newTitle -ne $originalTitle) {
                $tfile.Tag.Title = $newTitle
                $tfile.Save()
                Write-Host "Updated title: $($file.Name) [$originalTitle -> $newTitle]"
            }
        }
    }
    catch {
        Write-Warning "Failed to update $($file.Name): $_"
    }
}

Write-Host "Title underscore replacement completed."