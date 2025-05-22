$sourcePath = "Y:\"
$destinationPath = "U:\Artist"

# Create a hashtable to track folders we've already processed
$processedFolders = @{}

Get-ChildItem -Path $sourcePath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -like "*CD*" -and $_.Parent.FullName -ne $sourcePath
} | ForEach-Object {
    $parentFolder = $_.Parent.FullName
    
    # Skip if we've already processed this folder
    if (-not $processedFolders.ContainsKey($parentFolder)) {
        $processedFolders[$parentFolder] = $true
        
        try {
            if (Test-Path -Path $parentFolder -ErrorAction SilentlyContinue) {
                Write-Host "Attempting to move $parentFolder to $destinationPath"
                Move-Item -Path $parentFolder -Destination $destinationPath -Force -ErrorAction Stop
                Write-Host "Successfully moved $parentFolder to $destinationPath" -ForegroundColor Green
            } else {
                Write-Host "Folder does not exist: $parentFolder" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "Failed to move $parentFolder : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}