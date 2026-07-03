@echo off
echo ============================================
echo   Finanzas App - Servidor Web
echo ============================================
echo.
echo Abre tu navegador en:
echo   http://localhost:8080
echo.
echo Para acceder desde otro dispositivo en la misma red:
echo   http://TU_IP_LOCAL:8080
echo.
echo Presiona Ctrl+C para detener el servidor.
echo ============================================
echo.
cd build\web
C:\flutter\bin\dart run http_server -p 8080
