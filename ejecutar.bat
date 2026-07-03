@echo off
title Finanzas App - Ejecutar
color 0A

echo ========================================
echo    APP FINANZAS PERSONALES
echo ========================================
echo.
echo Iniciando aplicacion...
echo.

start "" "%~dp0build\windows\x64\runner\Release\finanzas_app.exe"
