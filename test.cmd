@echo off
rem SPDX-License-Identifier: MIT
call "%~dp0llmini.cmd" test %*
exit /b %errorlevel%
