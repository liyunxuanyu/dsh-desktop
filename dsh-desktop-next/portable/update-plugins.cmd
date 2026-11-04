@echo off
rem Refresh the plugin library this portable package carries (needs a network).
rem Usage: update-plugins.cmd [--latest] [package@version ...]
rem ASCII-only: see DSH-NEXT.cmd for why.
setlocal
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
set "RT=%DIR%\resources\runtime\x64\primary-runtime\dependencies"
set "PATH=%RT%\node\bin;%RT%\python;%PATH%"
set "NODE=%RT%\node\bin\node.exe"
if not exist "%NODE%" (
  echo The package is missing its bundled node: %NODE%
  exit /b 1
)
"%NODE%" "%DIR%\tools\refresh-library.mjs" %*
set "CODE=%ERRORLEVEL%"
endlocal & exit /b %CODE%
