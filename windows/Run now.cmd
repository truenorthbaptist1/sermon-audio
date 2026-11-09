@echo off
title Sermon audio - run now
cd /d "%LOCALAPPDATA%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\TNBC Sermon Audio\sermon-audio.ps1" -Show
echo.
pause
