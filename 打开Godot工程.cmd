@echo off
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0runtime-data\roaming"
set "LOCALAPPDATA=%~dp0runtime-data\local"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
start "" "%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe" --editor --path "%~dp0prototype"
endlocal
