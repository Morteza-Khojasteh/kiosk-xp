@echo off
title Clock System Kiosk
cd /d "%~dp0"

:: Check AutoHotkey is available
if exist "%~dp0AutoHotkey.exe" (
  start "" "%~dp0AutoHotkey.exe" "%~dp0ClockSystem.ahk"
  goto :end
)

:: Try system install
where AutoHotkey.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  start "" AutoHotkey.exe "%~dp0ClockSystem.ahk"
  goto :end
)

echo ERROR: AutoHotkey.exe not found.
echo.
echo Place AutoHotkey.exe in the same folder as START.bat
echo Download from: https://www.autohotkey.com/download/1.1/
echo Get: AutoHotkey_1.1.xx.xx.zip ^> extract AutoHotkeyU32.exe
echo Rename it to AutoHotkey.exe and place it here.
echo.
pause

:end
