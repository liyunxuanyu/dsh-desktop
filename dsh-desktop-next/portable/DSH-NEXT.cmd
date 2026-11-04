@echo off
rem DSH NEXT portable launcher (Windows x64).
rem Data, caches and plugins stay in this folder; run DSH-NEXT-reset.cmd to wipe user data.
rem This file is ASCII-only on purpose: cmd.exe decodes batch files with the console
rem code page, and a non-ASCII byte can swallow the start of the next line. The
rem Chinese documentation lives in README.md.
setlocal
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
set "DSH_DESKTOP_NEXT_HOME=%DIR%\home\data"
set "NPM_CONFIG_USERCONFIG=%DIR%\.npmrc"
if not exist "%DSH_DESKTOP_NEXT_HOME%" mkdir "%DSH_DESKTOP_NEXT_HOME%"
rem The application derives every store, cache and runtime path from this folder
rem (src/portable-environment.ts), so nothing is hard-coded here and a renamed or
rem moved package keeps working. The launcher only puts the bundled interpreters
rem first on PATH so plugins, skills and MCP servers resolve node / python.
set "RT=%DIR%\resources\runtime\x64\primary-runtime\dependencies"
if exist "%RT%\node\bin" set "PATH=%RT%\node\bin;%PATH%"
if exist "%RT%\python" set "PATH=%RT%\python;%RT%\python\Scripts;%PATH%"
if exist "%DIR%\DSH NEXT.exe" (
  start "" "%DIR%\DSH NEXT.exe"
) else (
  start "" "%DIR%\dsh-desktop-next.exe"
)
endlocal
