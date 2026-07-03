@echo off
title Finanzas App - Recompilar
color 0D

echo ========================================
echo    RECOMPILAR APP FINANZAS
echo ========================================
echo.

set PATH=C:\flutter\bin;%PATH%

echo [1/2] Limpiando build anterior...
flutter clean
echo.

echo [2/2] Compilando para Windows...
flutter build windows --release
echo.

if errorlevel 1 (
    echo ERROR: Fallo al compilar
    pause
    exit /b 1
)

echo ========================================
echo    COMPILACION EXITOSA
echo ========================================
echo.
echo Ejecutable: build\windows\x64\runner\Release\finanzas_app.exe
echo.
pause
