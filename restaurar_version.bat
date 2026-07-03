@echo off
setlocal enabledelayedexpansion
title PokeFinanzas - Restaurar Version Web
color 0E

echo ========================================
echo    RESTAURAR VERSION WEB
echo ========================================
echo.

set "VER_DIR=versiones"

if not exist "%VER_DIR%\next.txt" (
    echo No hay versiones guardadas.
    echo Ejecuta guardar_version.bat primero.
    pause
    exit /b 1
)

set /p TOTAL=<"%VER_DIR%\next.txt"
set /a TOTAL=TOTAL-1

if %TOTAL%==0 (
    echo No hay versiones guardadas.
    pause
    exit /b 1
)

echo Versiones disponibles:
echo.

for /l %%i in (1,1,%TOTAL%) do (
    if exist "%VER_DIR%\v%%i" (
        echo   v%%i
        if exist "%VER_DIR%\historial.txt" (
            for /f "tokens=*" %%j in ('findstr /c:"v%%i:" "%VER_DIR%\historial.txt" 2^>nul') do (
                echo          %%j
            )
        )
    )
)

echo.
set /p VERSION="Numero de version a restaurar (ej: 3): "

if "!VERSION!"=="" (
    echo Cancelado.
    pause
    exit /b 0
)

if not exist "%VER_DIR%\v!VERSION!" (
    echo.
    echo ERROR: La version v!VERSION! no existe.
    pause
    exit /b 1
)

echo.
echo Restaurando v!VERSION! a build\web...
echo.

if exist "build\web" rmdir /s /q "build\web"

robocopy "%VER_DIR%\v!VERSION!" "build\web" /E /NFL /NDL /NJH /NJS /nc /ns /np
echo   Copiado OK

echo [!date! !time!] RESTAURADA v!VERSION!>> "%VER_DIR%\historial.txt"

echo.
echo ========================================
echo    v!VERSION! RESTAURADA
echo ========================================
echo.
echo ¿Desplegar en Firebase Hosting? (s/n)
set /p DEPLOY=
if /i "!DEPLOY!"=="s" (
    echo.
    echo Desplegando en Firebase...
    call firebase deploy --only hosting
    if errorlevel 1 (
        echo ERROR: Fallo al desplegar
    ) else (
        echo ¡Desplegado con exito!
    )
)
echo.
pause
