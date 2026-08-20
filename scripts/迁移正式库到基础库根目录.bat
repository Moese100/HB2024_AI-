@echo off
chcp 65001 >nul
setlocal
set "SCRIPT_DIR=%~dp0"
echo This is a one-time HB2024 repository root migration.
echo The old nested repository will be retained until you verify daily sync.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Migrate-ToBaseRoot.ps1"
set "CODE=%ERRORLEVEL%"
echo.
if not "%CODE%"=="0" (
  echo Migration did not complete. Check the migration log in the base directory.
) else (
  echo Migration completed. Check the migration log, then return to this chat.
)
pause
exit /b %CODE%
