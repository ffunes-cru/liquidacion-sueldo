@echo off
echo ===================================================
echo   Compilando Sistema de Liquidacion para Windows
echo ===================================================

if not exist build mkdir build
cd build

echo.
echo [1/3] Configurando CMake...
cmake .. -DCMAKE_BUILD_TYPE=Release

if %ERRORLEVEL% NEQ 0 (
    echo Error al configurar CMake. Asegurate de tener Qt6 y CMake en el PATH.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Compilando ejecutable...
cmake --build . --config Release

if %ERRORLEVEL% NEQ 0 (
    echo Error en la compilacion.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] Desplegando DLLs de Qt (windeployqt)...
windeployqt.exe --qmldir ..\qml release\liquidacion_sueldos_app.exe

echo.
echo ===================================================
echo   Compilacion completada con exito!
echo   El ejecutable listo esta en: build\release\
echo ===================================================
pause
