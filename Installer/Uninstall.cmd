@echo off
set /p "CF_GAME=Scrap Mechanic folder (Steam - Manage - Browse local files): "
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-ColourForge.ps1" -GamePath "%CF_GAME%"
pause
