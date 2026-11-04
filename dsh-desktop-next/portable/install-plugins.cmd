@echo off
rem 把离线插件包里的插件装进便捷包当前的 Profile（不需要网络）
rem 用法：install-plugins.cmd [--list] [插件包目录]
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
if "%BUNDLE%"=="" (
  if exist "%DIR%\plugins-offline" (set "BUNDLE=%DIR%\plugins-offline") else (set "BUNDLE=%DIR%")
)
if not exist "%BUNDLE%" (echo 找不到插件包目录：%BUNDLE% & exit /b 1)

if "%LIST_ONLY%"=="1" (
  echo 离线插件包：%BUNDLE%
  for %%f in ("%BUNDLE%\*.tgz") do echo   %%~nxf
  exit /b 0
)

if "%DSH_NEXT_PACKAGE%"=="" set "DSH_NEXT_PACKAGE=%DIR%"
if "%DSH_DESKTOP_NEXT_HOME%"=="" set "DSH_DESKTOP_NEXT_HOME=%DSH_NEXT_PACKAGE%\home\data"
set "NPM_CONFIG_USERCONFIG=%DSH_NEXT_PACKAGE%\.npmrc"
set "NPM_CONFIG_STORE_DIR=%BUNDLE%\store"
set "NPM_CONFIG_CACHE=%BUNDLE%\cache"
set "PROFILE_DIR=%DSH_DESKTOP_NEXT_HOME%\profiles\desktop"
set "NODE=%DSH_NEXT_PACKAGE%\resources\runtime\x64\primary-runtime\dependencies\node\bin\node.exe"
set "PNPM=%DSH_NEXT_PACKAGE%\resources\app.asar.unpacked\node_modules\pnpm\bin\pnpm.mjs"
if not exist "%NODE%" (echo 便捷包缺少内置 node & exit /b 1)
if not exist "%PROFILE_DIR%" (echo Profile 尚未创建，请先启动一次便捷包 & exit /b 1)
echo 将要安装：
for %%f in ("%BUNDLE%\*.tgz") do echo   %%~nxf
cd /d "%PROFILE_DIR%"
for %%f in ("%BUNDLE%\*.tgz") do (
  echo 安装 %%~nxf
  "%NODE%" "%PNPM%" add --offline --store-dir "%BUNDLE%\store" "%%f"
)
echo 完成。重新启动便捷包使插件生效。
endlocal
