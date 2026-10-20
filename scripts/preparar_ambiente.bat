@echo off
rem Prepara o ambiente completo (Python, dependencias, .env, MongoDB, Godot)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0daybloom.ps1" preparar %*
set CODIGO=%ERRORLEVEL%
if "%DAYBLOOM_SEM_PAUSA%"=="" pause
exit /b %CODIGO%
