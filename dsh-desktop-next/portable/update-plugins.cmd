@echo off
rem 更新便捷包自带的插件库：重新解析、下载并写回 registry/（需要联网）
rem 用法：update-plugins.cmd [--latest] [插件@版本 ...]
setlocal
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
set "RT=%DIR%\resources\runtime\x64\primary-runtime\dependencies"
set "PATH=%RT%\node\bin;%RT%\python;%PATH%"
set "NODE=%RT%\node\bin\node.exe"
if not exist "%NODE%" (echo 便捷包缺少内置 node，无法更新插件库 & exit /b 1)
"%NODE%" "%DIR%\tools\refresh-library.mjs" %*
endlocal
