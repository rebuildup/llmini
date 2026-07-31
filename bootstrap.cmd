@echo off
rem SPDX-License-Identifier: MIT
call "%~dp0llmini.cmd" bootstrap %*
exit /b %errorlevel%
