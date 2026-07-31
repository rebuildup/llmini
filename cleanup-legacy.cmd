@echo off
setlocal
where pwsh.exe >nul 2>&1
if %errorlevel% equ 0 (set "PS_EXE=pwsh.exe") else (set "PS_EXE=powershell.exe")
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\llmini.ps1" cleanup-legacy %*
exit /b %errorlevel%
