@echo off
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0runtime-data\roaming"
set "LOCALAPPDATA=%~dp0runtime-data\local"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if not exist "%~dp0artifacts" mkdir "%~dp0artifacts"
if not exist "%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe" (
    echo Godot is missing. Run: python tools\bootstrap_godot.py
    pause
    exit /b 1
)
start "" "%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0prototype" --log-file "%~dp0artifacts\game.log"
endlocal
