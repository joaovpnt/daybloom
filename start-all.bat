@echo off
rem Daybloom: verifica MongoDB e Ollama, inicia o backend local e abre o jogo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\daybloom.ps1" jogo %*
set CODIGO=%ERRORLEVEL%
if "%DAYBLOOM_SEM_PAUSA%"=="" pause
exit /b %CODIGO%
