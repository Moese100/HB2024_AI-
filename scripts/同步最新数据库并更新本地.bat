@echo off
chcp 65001 >nul
setlocal
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "REPO_ROOT=%%~fI"

echo ----------------------------------------
echo HB2024 AI定额数据库：同步GitHub正式库
echo ----------------------------------------

where git >nul 2>nul
if errorlevel 1 (
  echo 未检测到Git。请通过GitHub Desktop打开本正式库后再运行本文件。
  pause
  exit /b 2
)

if not exist "%REPO_ROOT%\.git" (
  echo 当前文件未放在GitHub正式数据库库的 scripts 文件夹中，已停止。
  pause
  exit /b 2
)

echo 正在从GitHub拉取修复版JSON数据库...
git -C "%REPO_ROOT%" pull --ff-only
if errorlevel 1 (
  echo.
  echo 未能拉取最新版本。请确认电脑已联网、GitHub Desktop已登录且本地没有自行修改冲突。
  pause
  exit /b 3
)

echo.
echo 已拉取最新版，开始核验六个正式JSON目录...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Sync-HB2024Database.ps1"
set "CODE=%ERRORLEVEL%"
echo.
if not "%CODE%"=="0" (
  echo 同步核验未通过，错误代码：%CODE%。请查看正式库根目录中的核验日志。
) else (
  echo 同步完成。日常检索请只使用当前正式库，原始PDF不受本操作影响。
)
pause
exit /b %CODE%
