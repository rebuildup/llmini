@echo off
rem SPDX-License-Identifier: MIT
call "%~dp0llmini.cmd" stop %*
exit /b %errorlevel%
