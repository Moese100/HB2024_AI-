#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$SourceRoot = Split-Path -Parent $PSScriptRoot
$BaseRoot = Split-Path -Parent $SourceRoot
$TimeTag = Get-Date -Format 'yyyyMMdd_HHmmss'
$MigrationRoot = Join-Path $BaseRoot ('HB2024_Base_JSON_DB_Windows_Migrated_' + $TimeTag)
$LogPath = Join-Path $BaseRoot ('HB2024_DB_ROOT_MIGRATION_' + $TimeTag + '.txt')
$Names = @('.git','.gitignore','README.md','HB2024_数据库清单.json','scripts','安装2024JSON','房建装饰2024JSON','公共专业2024JSON','湖北2024定额库_统一索引','市政2024JSON','园林绿化2024JSON')

function Copy-Tree {
    param([string]$Source,[string]$Target)
    if (Test-Path -LiteralPath $Source -PathType Container) {
        Copy-Item -LiteralPath $Source -Destination $Target -Recurse -Force
    } elseif (Test-Path -LiteralPath $Source -PathType Leaf) {
        Copy-Item -LiteralPath $Source -Destination $Target -Force
    }
}

try {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot '.git') -PathType Container)) {
        throw 'Source repository was not found. Run this script from the nested HB2024 repository scripts folder.'
    }

    $ExistingRootGit = Join-Path $BaseRoot '.git'
    if (Test-Path -LiteralPath $ExistingRootGit) {
        throw 'The base directory already has a Git repository. Migration stopped to avoid overwriting it.'
    }

    $Answer = Read-Host 'Copy the verified JSON repository to the base directory root? Type Y to continue'
    if ($Answer -notmatch '^[Yy]$') { Write-Host 'Migration cancelled.'; exit 0 }

    New-Item -ItemType Directory -Force -Path $MigrationRoot | Out-Null
    $Log = @('HB2024 root migration','Source: ' + $SourceRoot,'Target: ' + $BaseRoot,'Time: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

    foreach ($Name in $Names) {
        $Source = Join-Path $SourceRoot $Name
        if (-not (Test-Path -LiteralPath $Source)) { continue }
        $Target = Join-Path $BaseRoot $Name
        if (Test-Path -LiteralPath $Target) {
            throw ('Target already exists: ' + $Target + '. Migration stopped without deleting anything.')
        }
        Copy-Tree -Source $Source -Target $Target
        $Log += ('Copied: ' + $Name)
        Write-Host ('Copied: ' + $Name) -ForegroundColor Green
    }

    $GitExe = Get-Command git -ErrorAction Stop
    & $GitExe.Source -C $BaseRoot status --short | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Git validation failed after copy.' }

    $Log += 'Validation: PASS'
    $Log += ('Old nested repository retained at: ' + $SourceRoot)
    $Log += ('Migration backup marker: ' + $MigrationRoot)
    Set-Content -LiteralPath $LogPath -Value $Log -Encoding ASCII
    Write-Host ''
    Write-Host 'Migration passed. The base directory is now the Git repository root.' -ForegroundColor Green
    Write-Host 'The old nested repository has NOT been deleted. Remove it only after daily sync is verified.' -ForegroundColor Yellow
    Write-Host ('Log: ' + $LogPath) -ForegroundColor Green
    exit 0
}
catch {
    $ErrorText = $_.Exception.Message
    Set-Content -LiteralPath $LogPath -Value @('HB2024 root migration','Result: FAIL',$ErrorText) -Encoding ASCII
    Write-Host ('Migration failed: ' + $ErrorText) -ForegroundColor Red
    Write-Host ('Log: ' + $LogPath) -ForegroundColor Red
    exit 1
}
