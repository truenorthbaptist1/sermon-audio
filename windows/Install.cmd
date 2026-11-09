@echo off
title True North Baptist Church - Sermon audio setup
rem a folder on a network drive (\\server\...) can't be the current folder; start from the program's own
cd /d "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
