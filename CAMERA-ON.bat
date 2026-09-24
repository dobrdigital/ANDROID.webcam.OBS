@echo off
rem ANDROID.webcam.OBS - double-click launcher. Optional argument: phone number (default = all phones).
set "PH=0"
if not "%~1"=="" set "PH=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0phonecam.ps1" start -Phone %PH%
"%SystemRoot%\System32\timeout.exe" /t 3 >nul
