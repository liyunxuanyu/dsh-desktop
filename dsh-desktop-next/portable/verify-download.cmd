@echo off
rem 校验从 Release 下载的压缩包是否完整（Windows）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify-download.ps1" %*
