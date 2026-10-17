[CmdletBinding()]
param(
    [switch]$Test,
    [string]$ConfigPath = ''
)

# Guard: when dot-sourced (e.g. by tests), expose functions but do not run main logic.
if ($MyInvocation.ScriptName -ne $PSCommandPath) { return }

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot '..\config.json'
}
. (Join-Path $PSScriptRoot 'Sync-NetTime.ps1')
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$projectRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $projectRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir 'winfakerct.log'
$defaultDateFile = Join-Path $logDir 'LastKnownDate.txt'
$defaultHistoryFile = Join-Path $logDir 'LastKnownDateHistory.txt'
$lastKnownDatePath = if ($config.LastKnownDateFile) { Join-Path $projectRoot $config.LastKnownDateFile } else { $defaultDateFile }
$lastKnownHistoryPath = if ($config.LastKnownDateHistoryFile) { Join-Path $projectRoot $config.LastKnownDateHistoryFile } else { $defaultHistoryFile }

function Write-Log([string]$Level,[string]$Message) {
    $line = '{0} [{1}] {2}' -f [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss zzz'),$Level,$Message
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
    Write-Output $line
}

function Get-LastKnownDate {
    if (-not (Test-Path -LiteralPath $lastKnownDatePath)) { return $null }
    $raw = (Get-Content -LiteralPath $lastKnownDatePath -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    try {
        return [DateTime]::Parse($raw)
    } catch {
        return $null
    }
}

function Save-LastKnownDate([DateTime]$Value) {
    $dir = Split-Path -Parent $lastKnownDatePath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Value.ToString('yyyy-MM-dd HH:mm:ss') | Set-Content -LiteralPath $lastKnownDatePath -Encoding UTF8
}

function Append-ValidDateHistory([DateTime]$Value) {
    $dir = Split-Path -Parent $lastKnownHistoryPath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $lastKnownHistoryPath)) {
        '# Timestamp of last valid system time' | Set-Content -LiteralPath $lastKnownHistoryPath -Encoding UTF8
    }
    $Value.ToString('yyyy-MM-dd HH:mm:ss') | Add-Content -LiteralPath $lastKnownHistoryPath -Encoding UTF8
    $history = @(Get-Content -LiteralPath $lastKnownHistoryPath)
    $entries = @($history | Select-Object -Skip 1 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 49)
    @($history[0]) + $entries | Set-Content -LiteralPath $lastKnownHistoryPath -Encoding UTF8
}

function Get-NetTimeInfo {
    try {
        $file = Find-NetTime -HintPath $config.NetTimePath
        if ($file) {
            return [pscustomobject]@{
                Installed = $true
                Path = $file.FullName
                Version = $file.VersionInfo.FileVersion
            }
        }
    } catch {
        Write-Log WARN "NetTime detection threw an exception: $($_.Exception.Message)"
    }

    return [pscustomobject]@{
        Installed = $false
        Path = $null
        Version = $null
    }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Log ERROR 'Run elevated; clock changes require administrator rights.'; exit 2 }

$thresholdYear = 2020
if ($config.ResetYearThreshold) { $thresholdYear = [int]$config.ResetYearThreshold }

# shortcut: 24h tolerance window; widen via RollbackToleranceHours if NetTime legitimately corrects a clock that is ahead.
$toleranceHours = 24
if ($config.RollbackToleranceHours) { $toleranceHours = [int]$config.RollbackToleranceHours }

$now = [DateTime]::Now
Write-Log INFO "WinFakeRct start. Current local time is $($now.ToString('yyyy-MM-dd HH:mm:ss'))"

$netTime = Get-NetTimeInfo
if ($netTime.Installed) {
    Write-Log INFO ("NetTime is installed: {0}; version={1}" -f $netTime.Path,$netTime.Version)
} else {
    Write-Log WARN 'NetTime is not installed or not found; no automatic time sync will be launched by this script.'
}

$lastKnown = Get-LastKnownDate
if (-not $lastKnown) {
    Write-Log WARN "No previous valid date was found. The script will not save a 2019-style date as the safe baseline."
}

# A rollback is suspected when the year is below the threshold, or when the clock
# moved backwards past the saved baseline by more than the tolerance window.
$rollback = $false
if ($now.Year -lt $thresholdYear) {
    $rollback = $true
} elseif ($lastKnown -and $now -lt $lastKnown.AddHours(-$toleranceHours)) {
    $rollback = $true
}

if ($rollback) {
    if (-not $lastKnown) {
        Write-Log ERROR "System date is invalid and there is no saved valid date to restore. No backup was written for this bad year."
        exit 1
    } else {
        Write-Log WARN "Detected suspicious system date: $($now.ToString('yyyy-MM-dd HH:mm:ss')). Restoring last known good date: $($lastKnown.ToString('yyyy-MM-dd HH:mm:ss'))"
        if ($Test) {
            Write-Log INFO "TEST: would restore system date to $($lastKnown.ToString('yyyy-MM-dd HH:mm:ss')); no change made."
        } else {
            Set-Date -Date $lastKnown | Out-Null
            Write-Log INFO ("Restored system date from safe backup: {0}" -f $lastKnown.ToString('yyyy-MM-dd HH:mm:ss'))
        }
    }
} else {
    # Forward-only baseline: never move the saved date backwards. A clock that is
    # within tolerance but behind the baseline is left as-is and does not overwrite it.
    if (-not $lastKnown -or $now -gt $lastKnown) {
        if ($Test) {
            Write-Log INFO "TEST: would update saved date to $($now.ToString('yyyy-MM-dd HH:mm:ss')); no change made."
        } else {
            Save-LastKnownDate -Value $now
            Append-ValidDateHistory -Value $now
            Write-Log INFO ("Current date looks valid. Updated saved date to {0} and appended history." -f $now.ToString('yyyy-MM-dd HH:mm:ss'))
        }
    } else {
        Write-Log INFO "Current date is within tolerance of the saved baseline; baseline left unchanged."
    }
}

Write-Log INFO 'WinFakeRct completed successfully.'
exit 0
