@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\verify_native.ps1"
set "verify_status=%ERRORLEVEL%"
pause
exit /b %verify_status%
