@echo off
rem Install the plugins of an offline bundle into this package's Profile (no network).
rem Usage: install-plugins.cmd [--list] [bundle-directory]
rem ASCII-only: see DSH-NEXT.cmd for why.
setlocal enabledelayedexpansion
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
set "LIST_ONLY=0"
set "BUNDLE="
for %%a in (%*) do (
  if /I "%%~a"=="--list" set "LIST_ONLY=1"
  if /I "%%~a"=="-l" set "LIST_ONLY=1"
  if not "%%~a"=="--list" if not "%%~a"=="-l" set "BUNDLE=%%~a"
)
if "%DSH_NEXT_PACKAGE%"=="" set "DSH_NEXT_PACKAGE=%DIR%"
if "%BUNDLE%"=="" (
  if exist "%DIR%\plugins-offline" (set "BUNDLE=%DIR%\plugins-offline") else (
    if exist "%DSH_NEXT_PACKAGE%\registry" (set "BUNDLE=%DSH_NEXT_PACKAGE%\registry") else (set "BUNDLE=%DIR%")
  )
)
if not exist "%BUNDLE%" (
  echo Offline bundle not found: %BUNDLE%
  exit /b 1
)

if "%LIST_ONLY%"=="1" (
  echo Offline bundle: %BUNDLE%
  for %%f in ("%BUNDLE%\*.tgz") do echo   %%~nxf
  exit /b 0
)

if "%DSH_DESKTOP_NEXT_HOME%"=="" set "DSH_DESKTOP_NEXT_HOME=%DSH_NEXT_PACKAGE%\home\data"
set "NPM_CONFIG_USERCONFIG=%DSH_NEXT_PACKAGE%\.npmrc"
rem Do not export NPM_CONFIG_CACHE / NPM_CONFIG_STORE_DIR: the upper-case names make
rem pnpm resolve cacheDir to an empty value. The paths travel as camelCase flags.
set "PROFILE_DIR=%DSH_DESKTOP_NEXT_HOME%\profiles\desktop"
set "RT=%DSH_NEXT_PACKAGE%\resources\runtime\x64\primary-runtime\dependencies"
set "PATH=%RT%\node\bin;%RT%\python;%PATH%"
set "NODE=%RT%\node\bin\node.exe"
set "PNPM=%DSH_NEXT_PACKAGE%\resources\app.asar.unpacked\node_modules\pnpm\bin\pnpm.mjs"
if not exist "%NODE%" (
  echo The package is missing its bundled node: %NODE%
  exit /b 1
)
if not exist "%PROFILE_DIR%" (
  echo No Profile yet: start the package once, then run this script again.
  exit /b 1
)
echo Installing:
for %%f in ("%BUNDLE%\*.tgz") do echo   %%~nxf
cd /d "%PROFILE_DIR%"
for %%f in ("%BUNDLE%\*.tgz") do (
  echo   %%~nxf
  "%NODE%" "%PNPM%" add --offline --store-dir "%BUNDLE%\store" --config.cacheDir="%BUNDLE%\cache" "%%f"
  if errorlevel 1 exit /b 1
)
echo Done. Restart the package so the plugins load.
endlocal
