@echo off
rem SPDX-License-Identifier: MIT
call "%~dp0llmini.cmd" start %*
exit /b %errorlevel%
