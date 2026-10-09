@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Join-Installer.ps1" -Directory "%~dp0."
set "TASK_JOIN_EXIT=%ERRORLEVEL%"
pause
exit /b %TASK_JOIN_EXIT%
