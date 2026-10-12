@echo off
rem Rebuilds assets/tracks/baked/ after editing assets/tracks.json.
rem Usage: tools\bake_tracks.bat            (all tracks)
rem        tools\bake_tracks.bat 3 5        (only some ids)
cd /d "%~dp0\.."
set GODOT="C:\sw-portable\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
%GODOT% --headless --path . -s tests/bake_tracks.gd -- %*
%GODOT% --headless --path . --import
