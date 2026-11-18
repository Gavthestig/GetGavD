@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-ColourForge.ps1" %*
if errorlevel 1 echo Setup did not finish. Read the message above.
pause
