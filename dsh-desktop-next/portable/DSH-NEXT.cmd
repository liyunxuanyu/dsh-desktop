@echo off
rem DSH NEXT 桌面版便捷启动器（Windows x64）
setlocal
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
set "DSH_DESKTOP_NEXT_HOME=%DIR%\home\data"
set "NPM_CONFIG_USERCONFIG=%DIR%\.npmrc"
if not exist "%DSH_DESKTOP_NEXT_HOME%" mkdir "%DSH_DESKTOP_NEXT_HOME%"
rem store、缓存、运行时都由程序自己从包目录解析（见 src/portable-environment.ts），
rem 这里不写死路径：包改名、移动或放在带空格的目录里都不会失效。
rem 启动器只把包内解释器提前放进 PATH，方便插件/技能/MCP 直接调用 node / python。
set "RT=%DIR%\resources\runtime\x64\primary-runtime\dependencies"
if exist "%RT%\node\bin" set "PATH=%RT%\node\bin;%PATH%"
if exist "%RT%\python" set "PATH=%RT%\python;%RT%\python\Scripts;%PATH%"
if exist "%DIR%\DSH NEXT.exe" (
  start "" "%DIR%\DSH NEXT.exe"
) else (
  start "" "%DIR%\dsh-desktop-next.exe"
)
endlocal
