@echo off
rem ANDROID.webcam.OBS - first run: installs scrcpy, detects phones, writes config.json
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0phonecam.ps1" setup
pause
