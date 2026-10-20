@echo off
rem Mostra o estado do ambiente local
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0daybloom.ps1" verificar %*
set CODIGO=%ERRORLEVEL%
if "%DAYBLOOM_SEM_PAUSA%"=="" pause
exit /b %CODIGO%
