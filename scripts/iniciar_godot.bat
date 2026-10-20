@echo off
rem Abre o jogo no Godot (use iniciar_editor.bat para o editor)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0daybloom.ps1" godot %*
set CODIGO=%ERRORLEVEL%
if "%DAYBLOOM_SEM_PAUSA%"=="" pause
exit /b %CODIGO%
