::set OUT_DIR=build\debug
::.\%OUT_DIR%\bezier.exe

@echo off

set OUT_DIR=build\debug
set SRC_DIR=src

if not exist %OUT_DIR% mkdir %OUT_DIR%

::odin run %SRC_DIR%\edge-flip -out:%OUT_DIR%\edge-flip.exe -vet -debug
odin run %SRC_DIR%\edge-split -out:%OUT_DIR%\edge-split.exe -vet -debug
IF %ERRORLEVEL% NEQ 0 exit /b 1

echo Debug build created in %OUT_DIR%