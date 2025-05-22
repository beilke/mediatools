# Set album artist and album name for all audio files in a folder

param (
    [Parameter(Mandatory = $true)]
    [string]$RootFolderPath
)

# Check if folder exists
if (-Not (Test-Path $RootFolderPath)) {
    Write-Error "Folder not found: $FolderPath"
    exit
}

# Get all subdirectories (each representing an album)
$folders = Get-ChildItem -Path $RootFolderPath -Directory

foreach ($folder in $folders) {
	
	# Get album name from folder name
	$albumName = (Split-Path -Leaf $folder) -replace '`', '' 
	$albumArtist = "Various Artists"

	# Load TagLib#
	Add-Type -Path "D:\dev\projects\taglib-sharp\src\TaglibSharp\bin\Release\net6.0\TagLibSharp.dll"  -ErrorAction SilentlyContinue

	# If TagLibSharp is not found, download it temporarily
	if (-not ("TagLib.File" -as [type])) {
		$taglibUrl = "https://github.com/mono/taglib-sharp/releases/download/2.3.0/TagLibSharp.dll"
		$dllPath = "$env:TEMP\TagLibSharp.dll"
		Invoke-WebRequest $taglibUrl -OutFile $dllPath
		Add-Type -Path $dllPath
	}

	# Get all supported audio files
	$audioExtensions = @("*.mp3", "*.flac", "*.m4a", "*.ogg", "*.wma")
	$files = Get-ChildItem -Path $folder -Recurse -Include $audioExtensions

	foreach ($file in $files) {
		try {
			$tfile = [TagLib.File]::Create($file.FullName)

			# Set album and album artist
			$tfile.Tag.Album = $albumName
			$tfile.Tag.AlbumArtists = @($albumArtist)
			
			# Remove the comment tag (if it exists)
			$tfile.Tag.Comment = ""

			$tfile.Save()
			Write-Host "Updated: $($file.Name)"
		}
		catch {
			Write-Warning "Failed to update $($file.Name): $_"
		}
	}
}
