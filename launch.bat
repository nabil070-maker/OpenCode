@echo off
setlocal enabledelayedexpansion

rem ---------------------------------------------------------------------
rem Resolve the portable root dynamically - never hard-code a drive letter
rem ---------------------------------------------------------------------
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "RUNTIME_DIR=%ROOT%\runtime\node"
set "APP_NPM_DIR=%ROOT%\app\npm"
set "CACHE_DIR=%ROOT%\cache\npm"
set "PROFILE_DIR=%ROOT%\profile"
set "CONFIG_HOME=%PROFILE_DIR%\.config"
set "DATA_HOME=%PROFILE_DIR%\.local\share"
set "CACHE_HOME=%PROFILE_DIR%\.cache"
set "TEMP_DIR=%ROOT%\temp"
set "WORKSPACE_DIR=%ROOT%\workspace"

set "NODE_EXE=%RUNTIME_DIR%\node.exe"
set "OPENCODE_CMD=%APP_NPM_DIR%\opencode.cmd"

rem ---------------------------------------------------------------------
rem Run setup if Node.js or OpenCode are missing
rem ---------------------------------------------------------------------
if not exist "%NODE_EXE%" goto RUN_SETUP
if not exist "%OPENCODE_CMD%" goto RUN_SETUP
goto SET_ENV

:RUN_SETUP
echo [INFO] Portable Node.js or OpenCode not found. Running setup...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\setup.ps1"
if errorlevel 1 (
    echo [ERROR] Setup failed. See output above.
    exit /b 1
)

rem re-check after setup
if not exist "%NODE_EXE%" (
    echo [ERROR] Node.js still missing after setup.
    exit /b 1
)
if not exist "%OPENCODE_CMD%" (
    echo [ERROR] OpenCode still missing after setup.
    exit /b 1
)

:SET_ENV
rem ---------------------------------------------------------------------
rem Portable environment - current process only, host is never modified
rem ---------------------------------------------------------------------
set "HOME=%PROFILE_DIR%"
set "USERPROFILE=%PROFILE_DIR%"
set "XDG_CONFIG_HOME=%CONFIG_HOME%"
set "XDG_DATA_HOME=%DATA_HOME%"
set "XDG_CACHE_HOME=%CACHE_HOME%"
set "TEMP=%TEMP_DIR%"
set "TMP=%TEMP_DIR%"
set "NPM_CONFIG_PREFIX=%APP_NPM_DIR%"
set "NPM_CONFIG_CACHE=%CACHE_DIR%"
set "OPENCODE_CONFIG_DIR=%CONFIG_HOME%\opencode"
set "PATH=%RUNTIME_DIR%;%APP_NPM_DIR%;%PATH%"

if not exist "%CONFIG_HOME%\opencode" mkdir "%CONFIG_HOME%\opencode" >nul 2>&1
if not exist "%DATA_HOME%\opencode" mkdir "%DATA_HOME%\opencode" >nul 2>&1
if not exist "%CACHE_HOME%\opencode" mkdir "%CACHE_HOME%\opencode" >nul 2>&1

rem ---------------------------------------------------------------------
rem Start OpenCode, forwarding all arguments and the exit code
rem ---------------------------------------------------------------------
pushd "%WORKSPACE_DIR%"
call "%OPENCODE_CMD%" %*
set "EXITCODE=%ERRORLEVEL%"
popd

endlocal & exit /b %EXITCODE%