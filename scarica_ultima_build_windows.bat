@echo off
cd /d "%~dp0"
echo Scarico l'ultima build Android e Windows...
python tool\sync_local_builds.py --windows
pause
