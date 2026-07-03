@echo off
setlocal enabledelayedexpansion
title PokeFinanzas - Guardar Version Web
color 0B

echo ========================================
echo    GUARDAR VERSION WEB
echo ========================================
echo.

set PATH=C:\flutter\bin;%PATH%
set "VER_DIR=versiones"
set "BUILD_WEB=build\web"
set MAX=5

if not exist "%BUILD_WEB%" (
    echo [!] No hay build web. Compilando primero...
    echo.
    flutter build web --release
    if errorlevel 1 (
        echo ERROR: Fallo al compilar
        pause
        exit /b 1
    )
)

if not exist "%VER_DIR%" mkdir "%VER_DIR%"

set NEXT=1
if exist "%VER_DIR%\next.txt" (
    set /p NEXT=<"%VER_DIR%\next.txt"
)

echo Siguiente version: v!NEXT!
echo.

set /p DESCRIPCION="Descripcion (Enter para fecha/hora): "
if "!DESCRIPCION!"=="" set DESCRIPCION=%date% %time%

echo.

if !NEXT! gtr %MAX% (
    echo [1/3] Limpiando versiones antiguas ^(maximo %MAX%^)...
    del /q "%VER_DIR%\v1\*" 2>nul
    rmdir /s /q "%VER_DIR%\v1" 2>nul

    for /l %%i in (2,1,%MAX%) do (
        set /a ANTERIOR=%%i-1
        if exist "%VER_DIR%\v%%i" (
            echo   v%%i -^> v!ANTERIOR!
            ren "%VER_DIR%\v%%i" "v!ANTERIOR!"
        )
    )
    set /a NEXT=%MAX%
    echo   OK
) else (
    echo [1/3] Primera vez o versiones disponibles...
)

echo [2/3] Guardando build web como v!NEXT!...
mkdir "%VER_DIR%\v!NEXT!"
robocopy "%BUILD_WEB%" "%VER_DIR%\v!NEXT!" /E /NFL /NDL /NJH /NJS /nc /ns /np
echo   OK

set /a SAVE_NEXT=NEXT+1
echo !SAVE_NEXT!> "%VER_DIR%\next.txt"

echo [!date! !time!] v!NEXT!: !DESCRIPCION!>> "%VER_DIR%\historial.txt"

echo.
echo ========================================
echo    v!NEXT! GUARDADA
echo ========================================
echo.
echo Carpeta: %VER_DIR%\v!NEXT!
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
