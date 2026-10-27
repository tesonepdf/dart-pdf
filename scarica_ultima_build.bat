@echo off
cd /d "%~dp0"
echo Scarico l'ultima build Android...
python tool\sync_local_builds.py
pause
