@echo off
rem SPDX-License-Identifier: MIT
call "%~dp0llmini.cmd" status %*
exit /b %errorlevel%
