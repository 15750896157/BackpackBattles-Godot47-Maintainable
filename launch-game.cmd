@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\ensure_art_imports.ps1"
if errorlevel 1 exit /b 1
start "" "%~dp0engine\Godot_v4.7-stable_win64.exe" --path "%~dp0project" --rendering-method gl_compatibility
