#requires -Version 5.1
<#!
.SYNOPSIS
核验HB2024正式JSON库的同目录Git同步结果。
.DESCRIPTION
本脚本必须放在正式库根目录的 scripts 文件夹内。
日常更新由“同步最新数据库并更新本地.bat”执行 git pull；本脚本随后核验六个正式JSON目录。
不复制、不移动、不删除任何PDF、ZIP、规则库或其他工作文件。
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TimeTag = Get-Date -Format 'yyyyMMdd_HHmmss'
$OfficialFolders = @(
    '安装2024JSON',
    '房建装饰2024JSON',
    '公共专业2024JSON',
    '湖北2024定额库_统一索引',
    '市政2024JSON',
    '园林绿化2024JSON'
)

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git') -PathType Container)) {
    throw "当前目录不是正式Git数据库库：$RepoRoot"
}
$missing = $OfficialFolders | Where-Object { -not (Test-Path -LiteralPath (Join-Path $RepoRoot $_) -PathType Container) }
if ($missing) { throw "正式库缺少目录：$($missing -join '、')" }

$logPath = Join-Path $RepoRoot "HB2024_AI数据库同步核验_$TimeTag.txt"
Start-Transcript -Path $logPath -Append | Out-Null
try {
    $total = 0
    foreach ($name in $OfficialFolders) {
        $count = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot $name) -Recurse -File |
            Where-Object { $_.Extension -in @('.json','.jsonl','.py') }).Count
        $total += $count
        Write-Host "已核验：$name（$count 个数据库文件）" -ForegroundColor Green
    }
    Write-Host "`n正式库同步核验通过，共发现 $total 个数据库相关文件。" -ForegroundColor Green
    Write-Host "核验日志：$logPath" -ForegroundColor Green
}
finally {
    Stop-Transcript | Out-Null
}
