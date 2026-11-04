@echo off
rem 把本目录携带的插件装进便捷包的当前激活 Profile（离线）
setlocal
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
if "%DSH_NEXT_PACKAGE%"=="" set "DSH_NEXT_PACKAGE=%DIR%"
set "BUNDLE=%DIR%\plugins-offline"
if not "%~1"=="" set "BUNDLE=%~1"
if "%DSH_DESKTOP_NEXT_HOME%"=="" set "DSH_DESKTOP_NEXT_HOME=%DSH_NEXT_PACKAGE%\home\data"
set "NPM_CONFIG_USERCONFIG=%DSH_NEXT_PACKAGE%\.npmrc"
set "NPM_CONFIG_STORE_DIR=%BUNDLE%\store"
set "NPM_CONFIG_CACHE=%BUNDLE%\cache"
set "PROFILE_DIR=%DSH_DESKTOP_NEXT_HOME%\profiles\desktop"
set "NODE=%DSH_NEXT_PACKAGE%\resources\runtime\x64\primary-runtime\dependencies\node\node.exe"
set "PNPM=%DSH_NEXT_PACKAGE%\resources\app.asar.unpacked\node_modules\pnpm\bin\pnpm.mjs"
if not exist "%NODE%" (echo 便捷包缺少内置 node & exit /b 1)
if not exist "%PROFILE_DIR%" (echo Profile 尚未创建，请先启动一次便捷包 & exit /b 1)
cd /d "%PROFILE_DIR%"
for %%f in ("%BUNDLE%\*.tgz") do (
  echo 安装 %%~nxf
  "%NODE%" "%PNPM%" add --offline --store-dir "%BUNDLE%\store" "%%f"
)
echo 完成。重新启动便捷包使插件生效。
endlocal
