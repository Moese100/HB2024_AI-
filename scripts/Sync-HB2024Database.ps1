#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TimeTag = Get-Date -Format 'yyyyMMdd_HHmmss'
$GitPath = Join-Path $RepoRoot '.git'
$LogPath = Join-Path $RepoRoot ("HB2024_DB_SYNC_VERIFY_" + $TimeTag + ".txt")

try {
    if (-not (Test-Path -LiteralPath $GitPath -PathType Container)) {
        throw 'This script must run from the scripts folder of the HB2024 Git repository.'
    }

    $RootDirectories = @(Get-ChildItem -LiteralPath $RepoRoot -Directory -Force |
        Where-Object { $_.Name -ne '.git' -and $_.Name -ne 'scripts' })

    if ($RootDirectories.Count -lt 6) {
        throw 'Repository validation failed: fewer than six database directories were found.'
    }

    $TotalFiles = 0
    $LogLines = @()
    $LogLines += 'HB2024 database sync verification'
    $LogLines += ('Repository: ' + $RepoRoot)
    $LogLines += ('Time: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

    foreach ($Directory in $RootDirectories) {
        $Count = @(Get-ChildItem -LiteralPath $Directory.FullName -Recurse -File -ErrorAction Stop |
            Where-Object { $_.Extension -in @('.json', '.jsonl', '.py') }).Count
        $TotalFiles += $Count
        $LogLines += ($Directory.Name + ': ' + $Count + ' database files')
        Write-Host ('Verified: ' + $Directory.Name + ' (' + $Count + ' database files)') -ForegroundColor Green
    }

    if ($TotalFiles -lt 180) {
        throw ('Repository validation failed: only ' + $TotalFiles + ' database files were found.')
    }

    $LogLines += ('Total database files: ' + $TotalFiles)
    $LogLines += 'Result: PASS'
    Set-Content -LiteralPath $LogPath -Value $LogLines -Encoding ASCII
    Write-Host ''
    Write-Host ('Verification passed. Total database files: ' + $TotalFiles) -ForegroundColor Green
    Write-Host ('Verification log: ' + $LogPath) -ForegroundColor Green
    exit 0
}
catch {
    $ErrorText = $_.Exception.Message
    Set-Content -LiteralPath $LogPath -Value @('HB2024 database sync verification','Result: FAIL',$ErrorText) -Encoding ASCII
    Write-Host ('Verification failed: ' + $ErrorText) -ForegroundColor Red
    Write-Host ('Verification log: ' + $LogPath) -ForegroundColor Red
    exit 1
}
