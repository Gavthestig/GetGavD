param([Parameter(Mandatory=$true)][string]$GamePath)
$ErrorActionPreference='Stop'
if (Get-Process ScrapMechanic -ErrorAction SilentlyContinue) { throw 'Close Scrap Mechanic first.' }
$root=[IO.Path]::GetFullPath($GamePath).TrimEnd('\')
$backup=Get-ChildItem -LiteralPath (Join-Path $root 'ColourForgeBackups') -Directory | Sort-Object Name -Descending | Where-Object { Test-Path (Join-Path $_.FullName 'manifest.json') } | Select-Object -First 1
if (!$backup) { throw 'No ColourForge setup backup found.' }
$manifest=Get-Content -LiteralPath (Join-Path $backup.FullName 'manifest.json') -Raw | ConvertFrom-Json
foreach ($item in $manifest) {
 $dest=[IO.Path]::GetFullPath((Join-Path $root $item.path))
 if (!$dest.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid backup path.' }
 if ($item.existed) { Copy-Item -LiteralPath (Join-Path $backup.FullName ('files/'+$item.path)) -Destination $dest -Force }
 elseif (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force }
}
Rename-Item -LiteralPath (Join-Path $backup.FullName 'manifest.json') -NewName 'manifest.restored.json'
Write-Host 'Restored the files from before the latest ColourForge setup.'

