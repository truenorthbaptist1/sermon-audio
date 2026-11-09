@echo off
title Sermon audio - run now
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\TNBC Sermon Audio\sermon-audio.ps1" -Show
echo.
pause
