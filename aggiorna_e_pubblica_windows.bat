@echo off
cd /d "%~dp0"
echo ===============================================
echo   Build Windows a comando in corso...
echo ===============================================
echo.
where python >nul 2>nul
if errorlevel 1 (
    echo ERRORE: Python non risulta installato o non e' nel PATH.
    pause
    exit /b 1
)
python aggiorna_e_pubblica.py windows
