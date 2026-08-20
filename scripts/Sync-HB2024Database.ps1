#requires -Version 5.1
<#!
.SYNOPSIS
将本仓库的HB2024修复版JSON库安全同步为Windows本机唯一正式库。
.DESCRIPTION
仅处理下列六个已确认的目录：安装2024JSON、房建装饰2024JSON、公共专业2024JSON、
湖北2024定额库_统一索引、市政2024JSON、园林绿化2024JSON。
同步前先备份旧JSON；仅删除这六个目录内旧的 .json、.jsonl、.py 文件，绝不删除PDF、
规则库、GBQ样表、待处理清单及02—06目录中的任何内容。
#>
[CmdletBinding()]
param(
    [string]$TargetRoot = 'D:\desktop\Codex共享文件夹\HB2024_AI套项数据库\01_基础定额库\HB2024_Base_JSON_DB_Windows',
    [switch]$SkipConfirm
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceRoot = Join-Path $RepoRoot 'Database'
$TimeTag = Get-Date -Format 'yyyyMMdd_HHmmss'
$OfficialFolders = @(
    '安装2024JSON',
    '房建装饰2024JSON',
    '公共专业2024JSON',
    '湖北2024定额库_统一索引',
    '市政2024JSON',
    '园林绿化2024JSON'
)

function Assert-RobocopyResult {
    param([int]$ExitCode, [string]$Operation)
    if ($ExitCode -gt 7) { throw "$Operation 失败。Robocopy退出代码：$ExitCode" }
}

function Get-DatabaseFiles {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction Stop |
        Where-Object { $_.Extension -in @('.json', '.jsonl', '.py') })
}

if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "未找到仓库正式数据库目录：$SourceRoot"
}
if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) {
    throw "未找到已确认的正式库目录：$TargetRoot。请勿自行选择其他目录。"
}

$sourceMissing = $OfficialFolders | Where-Object { -not (Test-Path -LiteralPath (Join-Path $SourceRoot $_) -PathType Container) }
if ($sourceMissing) { throw "仓库缺少正式库目录：$($sourceMissing -join '、')" }

$logPath = Join-Path (Split-Path -Parent $TargetRoot) "HB2024_AI数据库更新日志_$TimeTag.txt"
Start-Transcript -Path $logPath -Append | Out-Null
try {
    Write-Host '----------------------------------------' -ForegroundColor Cyan
    Write-Host 'HB2024 AI定额数据库：正式库安全替换工具' -ForegroundColor Cyan
    Write-Host "正式库目录：$TargetRoot"
    Write-Host '仅更新六个JSON目录；PDF、规则库、GBQ文件和02—06目录不会被触碰。' -ForegroundColor Yellow

    $plans = @()
    foreach ($name in $OfficialFolders) {
        $source = Join-Path $SourceRoot $name
        $target = Join-Path $TargetRoot $name
        $oldFiles = Get-DatabaseFiles -Path $target
        $newFiles = Get-DatabaseFiles -Path $source
        $plans += [PSCustomObject]@{Name=$name; Source=$source; Target=$target; OldCount=$oldFiles.Count; NewCount=$newFiles.Count}
    }

    Write-Host "`n本次正式替换范围：" -ForegroundColor Green
    $plans | ForEach-Object { Write-Host " - $($_.Name)：备份并替换旧JSON $($_.OldCount) 个，写入修复版文件 $($_.NewCount) 个" }
    Write-Host '不会删除任何PDF、ZIP、README、CSV或其他非JSON文件。' -ForegroundColor Green

    if (-not $SkipConfirm) {
        $answer = Read-Host "`n确认执行备份并替换六个正式JSON目录？输入 Y 后继续，其他输入取消"
        if ($answer -notmatch '^[Yy]$') { Write-Host '已取消，未修改任何文件。'; return }
    }

    $backupRoot = Join-Path (Split-Path -Parent $TargetRoot) ".HB2024_AI旧JSON本地备份\$TimeTag"
    foreach ($plan in $plans) {
        if (Test-Path -LiteralPath $plan.Target -PathType Container) {
            $backupDir = Join-Path $backupRoot $plan.Name
            New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
            Write-Host "正在备份旧JSON：$($plan.Name)"
            # 仅复制JSON类文件至备份，原目录的PDF及其他资料完全不动。
            Get-DatabaseFiles -Path $plan.Target | ForEach-Object {
                $relative = $_.FullName.Substring($plan.Target.Length).TrimStart('\')
                $dest = Join-Path $backupDir $relative
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
                Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
            }
        }
    }

    foreach ($plan in $plans) {
        New-Item -ItemType Directory -Force -Path $plan.Target | Out-Null
        Write-Host "正在移除旧JSON并写入修复版：$($plan.Name)"
        Get-DatabaseFiles -Path $plan.Target | Remove-Item -Force
        & robocopy $plan.Source $plan.Target /E /COPY:DAT /R:2 /W:1 /NFL /NDL /NJH /NJS | Out-Null
        Assert-RobocopyResult -ExitCode $LASTEXITCODE -Operation "更新 $($plan.Name)"
    }

    $manifest = Join-Path $SourceRoot 'HB2024_数据库清单.json'
    if (Test-Path -LiteralPath $manifest) {
        Copy-Item -LiteralPath $manifest -Destination (Join-Path $TargetRoot 'HB2024_数据库清单_正式库.json') -Force
    }

    Write-Host "`n正式库更新完成。" -ForegroundColor Green
    Write-Host "本次旧JSON备份：$backupRoot" -ForegroundColor Green
    Write-Host "更新日志：$logPath" -ForegroundColor Green
}
finally {
    Stop-Transcript | Out-Null
}
