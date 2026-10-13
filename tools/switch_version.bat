@echo off
rem Switches between the two versions of the game and refreshes Godot's import
rem cache (.godot/imported is not in git: without a reimport the other branch's
rem sprites are used, e.g. trucks drawn twice).
rem
rem   tools\switch_version.bat main            arcade version (320x240)
rem   tools\switch_version.bat enhanced        enhanced version (960x540)
rem   tools\switch_version.bat enhanced play   ...and start the game
rem
rem Set GODOT to your Godot console executable if it is not in the default place.
setlocal
cd /d "%~dp0\.."
if not defined GODOT set "GODOT=C:\sw-portable\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"

if "%~1"=="" (
    echo Usage: tools\switch_version.bat main^|enhanced [play]
    for /f %%b in ('git branch --show-current') do echo Current version: %%b
    exit /b 1
)
if not exist "%GODOT%" (
    echo Godot not found: "%GODOT%"
    echo Set the GODOT variable, e.g.  set GODOT=C:\path\to\Godot_console.exe
    exit /b 1
)

tasklist /FI "IMAGENAME eq Godot*" 2>nul | find /I "Godot" >nul
if not errorlevel 1 (
    echo Close the Godot editor / game first, then run this again.
    exit /b 1
)

git diff --quiet && git diff --cached --quiet
if errorlevel 1 (
    echo You have uncommitted changes. Commit or stash them first:
    git status --short
    exit /b 1
)

git switch %1 || exit /b 1
echo Reimporting assets for "%1" (about 30-60 seconds)...
"%GODOT%" --headless --path . --import >nul 2>&1
for /f %%b in ('git branch --show-current') do echo Ready: now on "%%b".

if /I "%~2"=="play" (
    start "" "%GODOT:_console=%" --path .
)
endlocal
