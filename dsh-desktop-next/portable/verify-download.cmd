@echo off
rem Verify a downloaded archive against SHA256SUMS.txt (delegates to verify-download.ps1).
rem ASCII-only: see DSH-NEXT.cmd for why.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify-download.ps1" %*
