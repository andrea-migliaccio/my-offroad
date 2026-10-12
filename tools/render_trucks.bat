@echo off
rem Regenerates assets/sprites/truck_*.png from the Blender model (no Blender UI needed).
rem Usage: double-click, or run from the project folder: tools\render_trucks.bat
cd /d "%~dp0\.."
set BLENDER="C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
%BLENDER% --background --factory-startup --python tools\blender\render_trucks.py -- --out _render\trucks || goto :err
python tools\compose_trucks.py _render\trucks assets\sprites || goto :err
python tools\gen_pixel_art.py || goto :err
echo Done: assets\sprites\truck_*.png
goto :eof
:err
echo FAILED
exit /b 1
