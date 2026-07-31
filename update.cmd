@echo off
rem SPDX-License-Identifier: MIT
call "%~dp0llmini.cmd" update %*
exit /b %errorlevel%
