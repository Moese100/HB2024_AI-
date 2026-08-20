@echo off
chcp 65001 >nul
setlocal
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "REPO_ROOT=%%~fI"

echo ----------------------------------------
echo HB2024 AI定额数据库：拉取最新版并同步到本地
echo ----------------------------------------

where git >nul 2>nul
if errorlevel 1 (
  echo 未检测到Git。请先安装Git for Windows，或使用GitHub Desktop克隆本仓库后再运行本文件。
  pause
  exit /b 2
)

echo 正在从GitHub检查并拉取数据库最新版本...
git -C "%REPO_ROOT%" pull --ff-only
if errorlevel 1 (
  echo.
  echo 未能拉取最新版本。请确认：
  echo 1. 电脑已联网；
  echo 2. 你已登录有该私有仓库访问权限的GitHub账号；
  echo 3. 本地仓库没有自行修改冲突。
  pause
  exit /b 3
)

echo.
echo 已取得GitHub最新版本，开始备份并同步到本地旧数据库...
call "%SCRIPT_DIR%一键同步到本地.bat"
exit /b %ERRORLEVEL%
