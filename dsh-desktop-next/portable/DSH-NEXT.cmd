@echo off
rem DSH NEXT 桌面版便捷启动器（Windows x64）
setlocal
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
set "DSH_DESKTOP_NEXT_HOME=%DIR%\home\data"
set "NPM_CONFIG_USERCONFIG=%DIR%\.npmrc"
if not exist "%DSH_DESKTOP_NEXT_HOME%" mkdir "%DSH_DESKTOP_NEXT_HOME%"
rem pnpm 11 只从 pnpm-workspace.yaml（或命令行）读 storeDir/cacheDir；npmrc 与 NPM_CONFIG_* 都不生效。
for /d %%p in ("%DSH_DESKTOP_NEXT_HOME%\profiles\*") do (
  > "%%~p\pnpm-workspace.yaml" echo storeDir: %DIR%\registry\store
  >> "%%~p\pnpm-workspace.yaml" echo cacheDir: %DIR%\registry\cache
  >> "%%~p\pnpm-workspace.yaml" echo preferOffline: true
)
rem 把包内运行时放进 PATH：插件/技能/MCP 里直接写 node / python 也能命中包内的
set "RT=%DIR%\resources\runtime\x64\primary-runtime\dependencies"
if exist "%RT%\node\bin" set "PATH=%RT%\node\bin;%PATH%"
if exist "%RT%\python" set "PATH=%RT%\python;%RT%\python\Scripts;%PATH%"
if exist "%DIR%\DSH NEXT.exe" (
  start "" "%DIR%\DSH NEXT.exe"
) else (
  start "" "%DIR%\dsh-desktop-next.exe"
)
endlocal
