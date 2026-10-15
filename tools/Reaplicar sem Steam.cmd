@echo off
rem Depois de cada update do Spidy: abre o jogo direto pelo game-path.txt, sem Steam.
cd /d "%~dp0"
"%~dp0python\python.exe" -I -B "%~dp0sem_steam.py" "%~dp0."
pause
