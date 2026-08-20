#requires -Version 5.1
<#!
.SYNOPSIS
将本仓库的HB2024定额JSON修复版本安全同步到Windows本地旧库。
.DESCRIPTION
脚本不删除本地任何文件。每次更新前，先把将被更新的目录备份到
目标根目录\.HB2024_AI更新备份\时间戳\，再从仓库的 Database 目录覆盖更新。
首次运行会要求确认目标根目录；以后可直接双击“scripts\一键同步到本地.bat”。
#>
[CmdletBinding()]
param(
    [string]$TargetRoot = 'D:\desktop\Codex共享文件夹\HB2024_AI套项数据库',
    [switch]$SkipConfirm
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceRoot = Join-Path $RepoRoot 'Database'
$TimeTag = Get-Date -Format 'yyyyMMdd_HHmmss'

function Assert-RobocopyResult {
    param([int]$ExitCode, [string]$Operation)
    # Robocopy: 0-7 are successful outcomes (including copied files / minor extras).
    if ($ExitCode -gt 7) { throw "$Operation 失败。Robocopy退出代码：$ExitCode" }
}

function Find-ExistingFolder {
    param([string]$Root, [string]$FolderName)
    $direct = Join-Path $Root $FolderName
    if (Test-Path -LiteralPath $direct -PathType Container) { return $direct }
    $found = Get-ChildItem -LiteralPath $Root -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $FolderName } | Select-Object -First 1
    if ($null -ne $found) { return $found.FullName }
    return $direct
}

if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "未找到仓库更新目录：$SourceRoot。请确认脚本位于完整数据库仓库的 scripts 文件夹中。"
}

if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) {
    $inputPath = Read-Host "未找到默认本地目录。请输入HB2024_AI套项数据库的完整路径"
    if ([string]::IsNullOrWhiteSpace($inputPath) -or -not (Test-Path -LiteralPath $inputPath -PathType Container)) {
        throw '目标目录不存在，已取消更新。'
    }
    $TargetRoot = $inputPath
}

$logPath = Join-Path $TargetRoot "HB2024_AI数据库更新日志_$TimeTag.txt"
Start-Transcript -Path $logPath -Append | Out-Null
try {
    Write-Host '----------------------------------------' -ForegroundColor Cyan
    Write-Host 'HB2024 AI定额数据库：安全更新工具' -ForegroundColor Cyan
    Write-Host "本地数据库根目录：$TargetRoot"
    Write-Host "仓库更新目录：$SourceRoot"
    Write-Host '规则：先备份、后更新；不删除本地已有文件。' -ForegroundColor Yellow

    $folders = Get-ChildItem -LiteralPath $SourceRoot -Directory | Sort-Object Name
    if ($folders.Count -eq 0) { throw "更新目录中未发现数据库文件夹：$SourceRoot" }

    $plans = @()
    foreach ($folder in $folders) {
        $destination = Find-ExistingFolder -Root $TargetRoot -FolderName $folder.Name
        $exists = Test-Path -LiteralPath $destination -PathType Container
        $plans += [PSCustomObject]@{ Name=$folder.Name; Source=$folder.FullName; Destination=$destination; Exists=$exists }
    }

    Write-Host "`n本次将同步以下数据库目录：" -ForegroundColor Green
    $plans | ForEach-Object {
        $state = if ($_.Exists) { '更新原有目录' } else { '创建新目录' }
        Write-Host " - $($_.Name)：$state"
    }

    if (-not $SkipConfirm) {
        $answer = Read-Host "`n确认执行备份和同步？输入 Y 后继续，其他输入取消"
        if ($answer -notmatch '^[Yy]$') { Write-Host '已取消，未修改任何文件。'; return }
    }

    $backupRoot = Join-Path $TargetRoot ".HB2024_AI更新备份\$TimeTag"
    foreach ($plan in $plans) {
        if ($plan.Exists) {
            $backupDir = Join-Path $backupRoot $plan.Name
            New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
            Write-Host "正在备份：$($plan.Name)"
            & robocopy $plan.Destination $backupDir /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
            Assert-RobocopyResult -ExitCode $LASTEXITCODE -Operation "备份 $($plan.Name)"
        }
    }

    foreach ($plan in $plans) {
        New-Item -ItemType Directory -Force -Path $plan.Destination | Out-Null
        Write-Host "正在更新：$($plan.Name)"
        # /E: 包含子目录；不使用 /MIR，保证不删除用户本地文件。
        # /IS: 同尺寸同日期时仍复制，确保仓库版本完整写入目标目录。
        & robocopy $plan.Source $plan.Destination /E /COPY:DAT /IS /R:2 /W:1 /NFL /NDL /NJH /NJS | Out-Null
        Assert-RobocopyResult -ExitCode $LASTEXITCODE -Operation "更新 $($plan.Name)"
    }

    $manifest = Join-Path $SourceRoot 'HB2024_数据库清单.json'
    if (Test-Path -LiteralPath $manifest) {
        Copy-Item -LiteralPath $manifest -Destination (Join-Path $TargetRoot 'HB2024_数据库清单_最近同步.json') -Force
    }

    Write-Host "`n同步完成。备份位置：$backupRoot" -ForegroundColor Green
    Write-Host "更新日志：$logPath" -ForegroundColor Green
}
finally {
    Stop-Transcript | Out-Null
}
