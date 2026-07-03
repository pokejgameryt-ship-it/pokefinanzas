@echo off
setlocal enabledelayedexpansion
title PokeFinanzas - Versiones Guardadas
color 0A

echo ========================================
echo    VERSIONES WEB GUARDADAS
echo ========================================
echo.

set "VER_DIR=versiones"

if not exist "%VER_DIR%\next.txt" (
    echo No hay versiones guardadas.
    echo Ejecuta guardar_version.bat para crear una.
    pause
    exit /b 0
)

set /p TOTAL=<"%VER_DIR%\next.txt"
set /a TOTAL=TOTAL-1

if %TOTAL%==0 (
    echo No hay versiones guardadas.
    pause
    exit /b 0
)

echo Total: %TOTAL% version(es) ^(maximo 5^)
echo.

for /l %%i in (1,1,5) do (
    if exist "%VER_DIR%\v%%i" (
        echo   v%%i
        if exist "%VER_DIR%\historial.txt" (
            for /f "tokens=*" %%j in ('findstr /c:"v%%i:" "%VER_DIR%\historial.txt" 2^>nul') do (
                echo          %%j
            )
        )
        echo.
    )
)

echo ========================================
echo.
echo   guardar_version.bat   = guardar build actual
echo   restaurar_version.bat = volver a una anterior
echo.
pause
