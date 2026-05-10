@echo off
REM Double-clic : build tous les exemples + lance la vitrine sur http://localhost:8000
REM Args optionnels forwardes (ex: build-local.bat -Force, build-local.bat -NoServe)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-local.ps1" %*
pause
