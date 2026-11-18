param([string]$GamePath, [switch]$ValidateOnly)
$ErrorActionPreference = 'Stop'
$u = 'c7cc62bc-0242-4c3e-a20b-6d7995375506'
$loaderHash = 'ED379E2FE4063A2E183A6240534E684E0FA942CBA061783C77BE8599F5B03E64'
if (Get-Process ScrapMechanic -ErrorAction SilentlyContinue) { throw 'Close Scrap Mechanic before installing.' }
if (!$GamePath) {
 $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
 $libraries = @($steam, "${env:ProgramFiles(x86)}\Steam") | Where-Object { $_ }
 if ($steam -and (Test-Path "$steam\steamapps\libraryfolders.vdf")) {
  $vdf = Get-Content "$steam\steamapps\libraryfolders.vdf" -Raw
  foreach ($m in [regex]::Matches($vdf, '"path"\s+"([^"]+)"')) { $libraries += $m.Groups[1].Value.Replace('\\','\') }
 }
 foreach ($library in $libraries) { $candidate = Join-Path $library 'steamapps\common\Scrap Mechanic'; if (Test-Path "$candidate\Release\ScrapMechanic.exe") { $GamePath = $candidate; break } }
 if (!$GamePath) { $GamePath = Read-Host 'Enter the Scrap Mechanic folder (Steam > Manage > Browse local files)' }
}
$gameRoot = [IO.Path]::GetFullPath($GamePath).TrimEnd('\')
function Target([string]$relative) {
 $p = [IO.Path]::GetFullPath((Join-Path $gameRoot $relative))
 if (!$p.StartsWith($gameRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid installation target.' }; return $p
}
$exe = Target 'Release/ScrapMechanic.exe'
$bytes = [IO.File]::ReadAllBytes($exe); $pe = [BitConverter]::ToInt32($bytes,60)
$stamp=[BitConverter]::ToUInt32($bytes,$pe+8); $imageSize=[BitConverter]::ToUInt32($bytes,$pe+80)
$supported=(($stamp -eq 1790011171 -and $imageSize -eq 29507584) -or ($stamp -eq 1794831492 -and $imageSize -eq 29540352))
if (!$supported) { throw 'ColourForge 1.1 supports Scrap Mechanic 1.0.6.889 and 1.0.7a.903. No files changed.' }
function ReadJson([string]$relative) { $text = Get-Content -LiteralPath (Target $relative) -Raw; return (($text -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n" | ConvertFrom-Json) }
foreach ($file in @('Data/Tools/ToolSets/core.json','ChallengeData/Tools/toolsets.json','Data/Gui/IconMap.xml','ChallengeData/Gui/IconMapChallenge.xml','Survival/CraftingRecipes/craftbot/craftbot_core.json','ChallengeData/Scripts/challenge/ChallengeWorld.lua')) { if (!(Test-Path (Target $file))) { throw "Required game file missing: $file" } }
if ($ValidateOnly) { Write-Host 'Supported game and required files found. Nothing changed.'; exit 0 }
# Fetch the unmodified dependency directly from its publisher; do not redistribute the Windows runtime.
$runtime = Target 'Release/vcruntime140_1.dll'
$haveLoader = (Test-Path $runtime) -and ((Get-FileHash -LiteralPath $runtime).Hash -eq $loaderHash)
$tempLoader = $null
if (!$haveLoader) {
 if ((Test-Path (Target 'Release/vcruntime140_1_.dll')) -and (Get-Item -LiteralPath (Target 'Release/vcruntime140_1_.dll')).VersionInfo.CompanyName -notmatch 'Microsoft') { throw 'Unknown alternate runtime found. No files changed.' }
 $runtimeInfo = (Get-Item -LiteralPath $runtime).VersionInfo
 if ($runtimeInfo.CompanyName -notmatch 'Microsoft') { throw 'Unknown runtime/loader found. No changes were made.' }
 $tempLoader = Join-Path $env:TEMP ('ColourForge-loader-'+[guid]::NewGuid()+'.dll')
 [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 Invoke-WebRequest 'https://github.com/QuestionableM/SM-DLL-Injector/releases/download/v1.8/vcruntime140_1.dll' -OutFile $tempLoader -UseBasicParsing
 if ((Get-FileHash -LiteralPath $tempLoader).Hash -ne $loaderHash) { Remove-Item -LiteralPath $tempLoader; throw 'Loader verification failed. No game files changed.' }
}
$backupRelative = 'ColourForgeBackups/'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6)
$backupRoot = Target $backupRelative
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$manifest = New-Object 'System.Collections.Generic.List[object]'
$recorded = @{}
function Record([string]$relative) {
 if ($recorded.ContainsKey($relative)) { return }; $recorded[$relative] = $true
 $dest = Target $relative; $exists = Test-Path -LiteralPath $dest
 if ($exists) { $b = Join-Path $backupRoot ('files/'+$relative); New-Item -ItemType Directory -Path (Split-Path $b) -Force | Out-Null; Copy-Item -LiteralPath $dest -Destination $b }
 $manifest.Add([pscustomobject]@{path=$relative; existed=$exists})
 @($manifest.ToArray()) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backupRoot 'manifest.json') -Encoding UTF8
}
function WriteBytes([string]$relative,[byte[]]$content) { Record $relative; $dest=Target $relative; New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null; [IO.File]::WriteAllBytes($dest,$content) }
function WriteText([string]$relative,[string]$content) { WriteBytes $relative ([Text.UTF8Encoding]::new($false).GetBytes($content)) }
function WriteJson([string]$relative,$data) { WriteText $relative (ConvertTo-Json -InputObject $data -Depth 100) }
function AddIcon([string]$xmlRelative,[string]$imageRelative) {
 $xmlPath=Target $xmlRelative; [xml]$xml=Get-Content -LiteralPath $xmlPath -Raw
 $group = $xml.SelectSingleNode('/MyGUI/Resource/Group')
 if (!$group) { throw "Missing icon group: $xmlRelative" }
 foreach ($old in @($xml.SelectNodes("//Index[@name='$u']"))) { [void]$old.ParentNode.RemoveChild($old) }
 $atlasPath=Join-Path (Split-Path $xmlPath) $group.texture
 $atlas=[Drawing.Bitmap]::new($atlasPath); $icon=[Drawing.Bitmap]::new((Join-Path $PSScriptRoot 'Payload/Mod/Gui/IconMap09.png'))
 $output=[Drawing.Bitmap]::new($atlas.Width,$atlas.Height+96);$graphics=[Drawing.Graphics]::FromImage($output)
 $graphics.DrawImageUnscaled($atlas,0,0); $graphics.DrawImage($icon,[Drawing.Rectangle]::new(0,$atlas.Height,96,96),[Drawing.Rectangle]::new(0,0,96,96),[Drawing.GraphicsUnit]::Pixel)
 $index=$xml.CreateElement('Index');$index.SetAttribute('name',$u);$frame=$xml.CreateElement('Frame');$frame.SetAttribute('point',"0 $($atlas.Height)");[void]$index.AppendChild($frame);[void]$group.AppendChild($index)
 $group.SetAttribute('texture',[IO.Path]::GetFileName($imageRelative))
 $memory=[IO.MemoryStream]::new();$output.Save($memory,[Drawing.Imaging.ImageFormat]::Png);WriteBytes $imageRelative $memory.ToArray()
 $graphics.Dispose();$atlas.Dispose();$icon.Dispose();$output.Dispose();$memory.Dispose()
 WriteText $xmlRelative $xml.OuterXml
}
try {
 Add-Type -AssemblyName System.Drawing
 if (!$haveLoader) { WriteBytes 'Release/vcruntime140_1_.dll' ([IO.File]::ReadAllBytes($runtime)); WriteBytes 'Release/vcruntime140_1.dll' ([IO.File]::ReadAllBytes($tempLoader)) }
 # Archive the old ColourForge bridge before enabling its newly named module.
 if (Test-Path (Target 'Release/DLLModules/Native-Drag-Bridge.dll')) { Record 'Release/DLLModules/Native-Drag-Bridge.dll'; Remove-Item -LiteralPath (Target 'Release/DLLModules/Native-Drag-Bridge.dll') }
 WriteBytes 'Release/DLLModules/ColourForge.dll' ([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'Payload/ColourForge.dll')))
 $modRoot=Join-Path $PSScriptRoot 'Payload/Mod'
 foreach ($file in Get-ChildItem -LiteralPath $modRoot -File -Recurse) {
  $relative=$file.FullName.Substring($modRoot.Length+1).Replace('\','/')
  $data=[IO.File]::ReadAllBytes($file.FullName)
  if ($file.Extension -in @('.lua','.gui','.json','.rend','.toolset','.tooldb','.xml')) { $text=[Text.Encoding]::UTF8.GetString($data).Replace('$CONTENT_DATA/','$GAME_DATA/Vaporator/'); $data=[Text.UTF8Encoding]::new($false).GetBytes($text) }
  WriteBytes ('Data/Vaporator/'+$relative) $data
 }
 $script=[IO.File]::ReadAllBytes((Target 'Data/Vaporator/Scripts/VaporatorDragTool.lua'))
 WriteBytes 'Data/Scripts/game/ColourForge.lua' $script
 WriteBytes 'ChallengeData/Scripts/game/ColourForge.lua' $script
 $entry=([IO.File]::ReadAllText((Join-Path $modRoot 'Tools/Database/ToolSets/vaporator-drag-v06.toolset')).Replace('$CONTENT_DATA/','$GAME_DATA/Vaporator/') | ConvertFrom-Json).toolList[0]
 $entry.script.file='$GAME_DATA/Scripts/game/ColourForge.lua'
 $core=ReadJson 'Data/Tools/ToolSets/core.json';$core.toolList=@($core.toolList | Where-Object uuid -ne $u)+@($entry);WriteJson 'Data/Tools/ToolSets/core.json' $core
 $entry.script.file='$CHALLENGE_DATA/Scripts/game/ColourForge.lua'
 WriteJson 'ChallengeData/Tools/ToolSets/colourforge.tools.json' @{toolList=@($entry)}
 $sets=ReadJson 'ChallengeData/Tools/toolsets.json';$sets.toolSetList=@($sets.toolSetList | Where-Object {$_ -ne '$CHALLENGE_DATA/Tools/ToolSets/colourforge.tools.json'})+@('$CHALLENGE_DATA/Tools/ToolSets/colourforge.tools.json');WriteJson 'ChallengeData/Tools/toolsets.json' $sets
 foreach ($path in @('Data/Gui/Language/English/InventoryItemDescriptions.json','Survival/Gui/Language/English/inventoryDescriptions.json','ChallengeData/Gui/Language/English/inventoryDescriptions.json')) {
  $d=ReadJson $path; $d | Add-Member -Force -NotePropertyName $u -NotePropertyValue @{title='ColourForge';upperCaseTitle='COLOURFORGE';description='Made by GetGavd. Q: colours; left drag: paint; right drag: erase; middle mouse: eyedropper.'};WriteJson $path $d
 }
 $recipes=ReadJson 'Survival/CraftingRecipes/craftbot/craftbot_core.json';$paint=@($recipes | Where-Object itemId -eq 'c60b9627-fc2b-4319-97c5-05921cb976c6')[0]
 if (!$paint) { throw 'Normal paint tool crafting recipe missing.' };$newRecipe=$paint | ConvertTo-Json -Depth 20 | ConvertFrom-Json;$newRecipe.itemId=$u
 WriteJson 'Survival/CraftingRecipes/craftbot/craftbot_core.json' (@($recipes | Where-Object itemId -ne $u)+@($newRecipe))
 $worldRelative='ChallengeData/Scripts/challenge/ChallengeWorld.lua';$world=[IO.File]::ReadAllText((Target $worldRelative))
 if (!$world.Contains($u)) {
  $pattern='(inventoryList\[index\] = \{ uuid = tool_painttool, quantity = 1 \}\s*index = index \+ 1)'
  if ($world -notmatch $pattern) { throw 'Unrecognised Challenge inventory script; setup cancelled.' }
  $world=[regex]::Replace($world,$pattern,('$1'+"`n`t`t`tinventoryList[index] = { uuid = sm.uuid.new(`"$u`"), quantity = 1 }`n`t`t`tindex = index + 1"));WriteText $worldRelative $world
 }
 AddIcon 'Data/Gui/IconMap.xml' 'Data/Gui/ColourForgeReleaseIcon.png'
 AddIcon 'ChallengeData/Gui/IconMapChallenge.xml' 'ChallengeData/Gui/ColourForgeReleaseIcon.png'
 # Archive the compiled registry so the new tool and icons are read on next launch.
 if (Test-Path (Target 'Cache/Bundle/core_data.cbo')) { Record 'Cache/Bundle/core_data.cbo';Remove-Item -LiteralPath (Target 'Cache/Bundle/core_data.cbo') }
 Write-Host "ColourForge installed. Start the game normally. Backup: $backupRoot"
} catch {
 $failure=$_
 foreach ($item in @($manifest.ToArray()) | Select-Object -Last 100000) { $dest=Target $item.path; if ($item.existed) { Copy-Item -LiteralPath (Join-Path $backupRoot ('files/'+$item.path)) -Destination $dest -Force } elseif (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force } }
 throw "Setup failed and its changes were rolled back: $failure"
} finally { if ($tempLoader -and (Test-Path -LiteralPath $tempLoader)) { Remove-Item -LiteralPath $tempLoader -Force } }
