@echo off
setlocal enableextensions
cd /d "%~dp0"
title Allinea la cartella a GitHub
echo ==========================================
echo   Allineo questa cartella a GitHub
echo ==========================================
echo Cartella: %cd%
echo.

where git >nul 2>&1
if errorlevel 1 (
  echo ERRORE: git non trovato.
  goto fine
)
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
  echo ERRORE: questa non e' una cartella git.
  echo Metti questo file nella cartella del progetto, quella che in VS Code si chiama tesone pdf.
  goto fine
)
git remote get-url origin | find /i "tesonepdf/dart-pdf" >nul
if errorlevel 1 (
  echo ERRORE: il remoto origin non e' tesonepdf/dart-pdf.
  goto fine
)

echo [1/4] Scarico lo stato di GitHub...
git fetch origin main
if errorlevel 1 goto errore

echo [2/4] Metto al sicuro quello che c'e' qui...
git stash push -u -m "allinea-automatico" -- . ":(exclude)%~nx0" >nul 2>&1
set "AHEAD=0"
for /f %%n in ('git rev-list --count origin/main..HEAD 2^>nul') do set "AHEAD=%%n"
if not "%AHEAD%"=="0" (
  for /f %%h in ('git rev-parse --short HEAD') do set "H=%%h"
  git branch "backup-locale-%H%" HEAD >nul 2>&1
  echo Commit solo locali: %AHEAD%. Salvati nel ramo backup-locale-%H%.
) else (
  echo Nessun commit solo locale da salvare.
)

echo [3/4] Allineo main a GitHub...
git checkout -q -B main origin/main
if errorlevel 1 goto errore
git branch --set-upstream-to=origin/main main >nul 2>&1
git config pull.rebase true
git config core.hooksPath .githooks

echo [4/4] Stato finale:
git status -sb
git log --oneline -1
echo.
echo Fatto. In VS Code il pulsante Sincronizza non deve piu' mostrare i numeri.
goto fine

:errore
echo.
echo ERRORE: qualcosa e' andato storto. Non e' stato perso niente.

:fine
echo.
pause
