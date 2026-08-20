@echo off
chcp 65001 >nul
setlocal
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Sync-HB2024Database.ps1"
set "CODE=%ERRORLEVEL%"
echo.
if not "%CODE%"=="0" (
  echo 同步未完成，错误代码：%CODE%。请查看数据库根目录中的更新日志。
) else (
  echo 同步流程已结束，请查看提示和更新日志。
)
pause
exit /b %CODE%
