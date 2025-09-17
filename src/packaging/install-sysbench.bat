@echo off
REM Wrapper so you can double-click or run from cmd even if PS execution policy is restricted
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-sysbench.ps1"
set ERR=%ERRORLEVEL%
if %ERR% NEQ 0 (
  echo Install failed with exit code %ERR%.
  exit /b %ERR%
)
echo Install completed.
