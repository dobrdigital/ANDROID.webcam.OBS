@echo off
rem ANDROID.webcam.OBS - double-click launcher. Optional argument: phone number (default = all phones).
set "PH=0"
if not "%~1"=="" set "PH=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0phonecam.ps1" wifi -Phone %PH%
pause
