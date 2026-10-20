@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem C.P Tuya Presence Sensor - one-click deploy for this SmartThings account.
rem Works with SmartThings CLI 2.1.2: --hub implies install.
rem No interactive channel/hub selection and no PowerShell/JSON parsing.
set "CHANNEL=cd373cad-c1db-4b2a-943b-6ed6fb51d2fa"
set "HUB=c9e6b370-41a7-499a-ae95-3496747cd165"
set "DRIVER_ID=7cd92d45-38da-4706-aa5d-f0443758e145"
set "EXPECTED_VERSION=v1.3.2"
set "SAMPLE_SENSOR=138b0efb-a58b-41f0-86d6-75d05fef9460"
set "ROOT=%~dp0"
set "RESULT=%ROOT%INSTALL-RESULT.txt"
set "LOG=%TEMP%\CP-Tuya-Presence-Deploy-%RANDOM%-%RANDOM%.log"
set "CHECK=%TEMP%\CP-Tuya-Presence-Installed-%RANDOM%-%RANDOM%.log"
set "STATE=%TEMP%\CP-Tuya-Presence-State-%RANDOM%-%RANDOM%.log"

cd /d "%ROOT%"
if errorlevel 1 goto :bad_directory
if exist "%RESULT%" del /q "%RESULT%" >nul 2>&1

echo ==========================================================
echo C.P Tuya Presence Sensor %EXPECTED_VERSION% - AUTO INSTALL
echo ==========================================================
echo [1/3] Checking SmartThings CLI...
where smartthings >nul 2>&1
if errorlevel 1 goto :no_cli
call smartthings --version > "%LOG%" 2>&1
if errorlevel 1 goto :cli_failed

echo [2/3] Uploading, assigning to CheesePowder, installing...
echo This may take a few minutes. Please wait for the result.
echo.>> "%LOG%"
echo === EDGE PACKAGE / CHANNEL ASSIGN / HUB INSTALL ===>> "%LOG%"
rem CLI 2.1.2: never combine --install and --hub.
rem --channel and --hub already perform assignment and installation.
call smartthings edge:drivers:package "." --channel "%CHANNEL%" --hub "%HUB%" >> "%LOG%" 2>&1
set "PACKAGE_RC=%ERRORLEVEL%"
if not "%PACKAGE_RC%"=="0" goto :package_failed

echo [3/3] Verifying that the driver is installed on the hub...
call smartthings edge:drivers:installed --verbose --hub "%HUB%" > "%CHECK%" 2>&1
set "VERIFY_RC=%ERRORLEVEL%"
echo.>> "%LOG%"
echo === INSTALLED DRIVERS VERIFICATION ===>> "%LOG%"
type "%CHECK%" >> "%LOG%"
if not "%VERIFY_RC%"=="0" goto :verify_failed
findstr /i /c:"%DRIVER_ID%" "%CHECK%" >nul 2>&1
if errorlevel 1 goto :not_installed

rem Optional cloud status check - may lag after a freshly installed driver.
echo.>> "%LOG%"
echo === SENSOR VERSION STATE (OPTIONAL) ===>> "%LOG%"
call smartthings devices:capability-status "%SAMPLE_SENSOR%" main buildbook37604.driverInformation -j > "%STATE%" 2>&1
set "STATE_RC=%ERRORLEVEL%"
type "%STATE%" >> "%LOG%"
if not "%STATE_RC%"=="0" goto :success_pending
findstr /i /c:"%EXPECTED_VERSION%" "%STATE%" >nul 2>&1
if errorlevel 1 goto :success_pending

goto :success_confirmed

:success_confirmed
echo.>> "%LOG%"
echo [OK] Hub installation confirmed; sensor version state is %EXPECTED_VERSION%.>> "%LOG%"
echo. 
echo [OK] Driver installed and version state confirmed: %EXPECTED_VERSION%
goto :success_end

:success_pending
echo.>> "%LOG%"
echo [WARNING] Hub installation confirmed, but device version state is not updated yet.>> "%LOG%"
echo.
echo [OK] Driver installation was confirmed on the hub.
echo [WARNING] Sensor version state has not updated yet. See log.
goto :success_end

:success_end
copy /y "%LOG%" "%RESULT%" >nul 2>&1
echo Deployment log: "%RESULT%"
echo No manual commands are needed.
goto :end_success

:bad_directory
echo [ERROR] Unable to open the extracted driver directory.
goto :end_failure

:no_cli
echo [ERROR] SmartThings CLI is not available in PATH.
echo [ERROR] SmartThings CLI not found.> "%LOG%"
goto :end_failure

:cli_failed
echo [ERROR] Could not start SmartThings CLI.
goto :end_failure

:package_failed
echo [ERROR] Deployment failed. CLI exit code: %PACKAGE_RC%
echo [ERROR] Packaging, channel assignment or hub installation failed. Exit %PACKAGE_RC%.>> "%LOG%"
goto :end_failure

:verify_failed
echo [ERROR] Upload returned success, but hub verification failed.
echo [ERROR] Could not check installed driver list.>> "%LOG%"
goto :end_failure

:not_installed
echo [ERROR] Driver ID not found on the hub after deployment.
echo [ERROR] Expected installed driver %DRIVER_ID% missing.>> "%LOG%"
goto :end_failure

:end_failure
if exist "%LOG%" copy /y "%LOG%" "%RESULT%" >nul 2>&1
if exist "%RESULT%" (
  echo.
  echo ===== INSTALLATION LOG =====
  type "%RESULT%"
  echo.
  echo Send INSTALL-RESULT.txt if troubleshooting is needed.
)
pause
exit /b 1

:end_success
pause
exit /b 0
