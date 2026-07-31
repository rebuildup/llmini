@echo off
rem SPDX-License-Identifier: MIT
setlocal
chcp 65001 >nul
where pwsh.exe >nul 2>&1
if errorlevel 1 (
    echo PowerShell 7 is required. Install it and ensure pwsh.exe is on PATH.
    exit /b 1
)
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\llmini.ps1" %*
exit /b %errorlevel%
