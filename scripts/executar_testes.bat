@echo off
rem Executa testes do backend (pytest) e do jogo (Godot headless)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0daybloom.ps1" testes %*
set CODIGO=%ERRORLEVEL%
if "%DAYBLOOM_SEM_PAUSA%"=="" pause
exit /b %CODIGO%
