@echo off
rem Abre o projeto no editor do Godot
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0daybloom.ps1" editor %*
set CODIGO=%ERRORLEVEL%
if "%DAYBLOOM_SEM_PAUSA%"=="" pause
exit /b %CODIGO%
