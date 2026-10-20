@echo off
setlocal
cd /d "%~dp0"

where smartthings >nul 2>&1
if errorlevel 1 (
  echo [ERROR] SmartThings CLI was not found.
  pause
  exit /b 1
)

echo C.P Tuya Presence Sensor v1.3.1
echo Reusing existing TYPE6 capability and presentation.
echo Deploying the same Edge driver to CheesePowder channel and main hub...
echo.

rem IMPORTANT: Do not query/parse JSON via PowerShell.
rem CLI 2.1.2 output with Korean is UTF-8 and was garbled by Windows PowerShell 5.1.
rem This command is documented for updating an existing Edge driver.
call smartthings edge:drivers:package "." --install --channel cd373cad-c1db-4b2a-943b-6ed6fb51d2fa --hub c9e6b370-41a7-499a-ae95-3496747cd165
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [ERROR] Driver upload or installation failed. Exit code: %EXIT_CODE%
  pause
  exit /b %EXIT_CODE%
)

echo.
echo [OK] Driver deployment command completed.
echo Check v1.3.1 in the SmartThings app and review logcat.
pause
exit /b 0
