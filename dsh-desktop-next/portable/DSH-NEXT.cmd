@echo off
rem DSH NEXT 桌面版便捷启动器（Windows x64）
setlocal
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
set "DSH_DESKTOP_NEXT_HOME=%DIR%\home\data"
set "NPM_CONFIG_USERCONFIG=%DIR%\.npmrc"
set "NPM_CONFIG_STORE_DIR=%DIR%\registry\store"
set "NPM_CONFIG_CACHE=%DIR%\registry\cache"
set "NPM_CONFIG_PREFER_OFFLINE=true"
if not exist "%DSH_DESKTOP_NEXT_HOME%" mkdir "%DSH_DESKTOP_NEXT_HOME%"
if exist "%DIR%\DSH NEXT.exe" (
  start "" "%DIR%\DSH NEXT.exe"
) else (
  start "" "%DIR%\dsh-desktop-next.exe"
)
endlocal
