@echo off
rem Inicia o backend local (FastAPI) em 127.0.0.1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0daybloom.ps1" backend %*
set CODIGO=%ERRORLEVEL%
if "%DAYBLOOM_SEM_PAUSA%"=="" pause
exit /b %CODIGO%
