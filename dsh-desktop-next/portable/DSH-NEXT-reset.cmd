@echo off
rem Delete the user data this package carries (sessions, credentials, plugin state,
rem caches) and keep the program, the runtimes and the plugin library.
rem Usage: DSH-NEXT-reset.cmd [--yes]
rem ASCII-only and label-free: see DSH-NEXT.cmd for why.
setlocal enabledelayedexpansion
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
set "ANSWER="
if /I not "%~1"=="--yes" set /p ANSWER=This deletes all user data under "%DIR%\home". Continue? [y/N]
if "%ANSWER%"=="" if /I "%~1"=="--yes" set "ANSWER=y"
if /I not "!ANSWER!"=="y" (
  echo Cancelled.
  exit /b 0
)
if exist "%DIR%\home" rmdir /s /q "%DIR%\home"
mkdir "%DIR%\home"
echo User data cleared: %DIR%\home
endlocal
