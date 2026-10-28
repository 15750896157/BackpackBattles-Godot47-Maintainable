@echo off
cd /d "%~dp0"
start "" "%~dp0engine\Godot_v4.7-stable_win64.exe" --editor --path "%~dp0project" --rendering-method gl_compatibility
