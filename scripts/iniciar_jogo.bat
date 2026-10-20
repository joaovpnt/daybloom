@echo off
rem Inicia backend e jogo juntos
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0daybloom.ps1" jogo %*
set CODIGO=%ERRORLEVEL%
if "%DAYBLOOM_SEM_PAUSA%"=="" pause
exit /b %CODIGO%
