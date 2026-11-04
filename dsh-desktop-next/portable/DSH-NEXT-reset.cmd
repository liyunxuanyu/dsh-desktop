@echo off
rem 清空包内用户数据（会话/凭据/插件配置/缓存），保留程序与运行时
setlocal
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
if /I not "%~1"=="--yes" (
  set /p ANSWER=将删除 %DIR%\home 下全部用户数据，继续？[y/N]
  if /I not "!ANSWER!"=="y" (echo 已取消 & exit /b 0)
)
if exist "%DIR%\home" rmdir /s /q "%DIR%\home"
mkdir "%DIR%\home"
echo 已清空用户数据：%DIR%\home
endlocal
