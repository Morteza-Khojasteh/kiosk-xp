@echo off
title Clock System - Compile to EXE
cd /d "%~dp0"

echo ========================================
echo  Clock System Kiosk - AHK to EXE Compiler
echo ========================================
echo.

:: Locate Ahk2Exe.exe — check common install paths first
set AHK2EXE=

if exist "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" (
  set AHK2EXE=C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe
)
if exist "C:\Program Files (x86)\AutoHotkey\Compiler\Ahk2Exe.exe" (
  set AHK2EXE=C:\Program Files (x86)\AutoHotkey\Compiler\Ahk2Exe.exe
)
if exist "%~dp0Ahk2Exe.exe" (
  set AHK2EXE=%~dp0Ahk2Exe.exe
)

if "%AHK2EXE%"=="" (
  echo ERROR: Ahk2Exe.exe not found.
  echo.
  echo This means AutoHotkey is not installed with its compiler,
  echo OR you only have the portable AutoHotkey.exe.
  echo.
  echo FIX 1 - Install full AutoHotkey ^(includes compiler^):
  echo   https://www.autohotkey.com/download/ahk-install.exe
  echo   Run installer, this adds Ahk2Exe.exe automatically.
  echo.
  echo FIX 2 - Download just the compiler:
  echo   https://github.com/AutoHotkey/Ahk2Exe/releases
  echo   Download Ahk2Exe.zip, extract Ahk2Exe.exe to this folder.
  echo.
  pause
  exit /b 1
)

echo Found compiler: %AHK2EXE%
echo.
echo Compiling ClockSystem.ahk -^> ClockSystem.exe ...
echo.

if exist "%~dp0icon.ico" (
  "%AHK2EXE%" /in "%~dp0ClockSystem.ahk" /out "%~dp0ClockSystem.exe" /icon "%~dp0icon.ico"
) else (
  "%AHK2EXE%" /in "%~dp0ClockSystem.ahk" /out "%~dp0ClockSystem.exe"
)

if exist "%~dp0ClockSystem.exe" (
  echo.
  echo SUCCESS! ClockSystem.exe created.
  echo.
  echo You can now delete ClockSystem.ahk from the deployment folder
  echo if you want ^(keep a backup copy elsewhere for future edits^).
  echo.
  echo Final folder for XP machines should contain:
  echo   ClockSystem.exe
  echo   setup.html
  echo   loading.html
  echo   offline.html
  echo   close.html
  echo   supermium\  ^(folder with chrome.exe^)
) else (
  echo.
  echo ERROR: Compilation failed. See output above.
)

echo.
pause
