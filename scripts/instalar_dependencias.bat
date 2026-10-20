@echo off
rem Cria backend\.venv e instala as dependencias Python
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0daybloom.ps1" instalar %*
set CODIGO=%ERRORLEVEL%
if "%DAYBLOOM_SEM_PAUSA%"=="" pause
exit /b %CODIGO%
