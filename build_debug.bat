@echo off

set OUT_DIR=build\debug
set SRC_DIR=src

if not exist %OUT_DIR% mkdir %OUT_DIR%

odin build %SRC_DIR%\bezier -out:%OUT_DIR%\bezier.exe -strict-style -vet -debug
IF %ERRORLEVEL% NEQ 0 exit /b 1

echo Debug build created in %OUT_DIR%