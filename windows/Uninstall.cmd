@echo off
title Sermon audio - remove
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Remove
echo.
pause
