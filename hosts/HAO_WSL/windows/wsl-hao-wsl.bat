@echo off
rem Launch NixOS-WSL (HAO_WSL) at logon and keep it alive.
rem The keep-alive script holds a long-lived wsl session; see windows\README.md.
start "" /min powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Users\admin\wsl-keepalive.ps1"
