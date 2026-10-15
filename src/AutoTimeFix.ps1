[CmdletBinding()]
param(
    [switch]$Test,
    [string]$ConfigPath = ''
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot '..\config.json'
}
. (Join-Path $PSScriptRoot 'Sync-NetTime.ps1')
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$projectRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $projectRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir 'AutoTimeFix.log'
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

$now = [DateTime]::Now
Write-Log INFO "AutoTimeFix start. Current local time is $($now.ToString('yyyy-MM-dd HH:mm:ss'))"

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

if ($now.Year -lt $thresholdYear) {
    if (-not $lastKnown) {
        Write-Log ERROR "System date is invalid and there is no saved valid date to restore. No backup was written for this bad year."
        exit 1
    } else {
        Write-Log WARN "Detected suspicious system date: $($now.ToString('yyyy-MM-dd HH:mm:ss')). Restoring last known good date: $($lastKnown.ToString('yyyy-MM-dd HH:mm:ss'))"
        Set-Date -Date $lastKnown | Out-Null
        Write-Log INFO ("Restored system date from safe backup: {0}" -f $lastKnown.ToString('yyyy-MM-dd HH:mm:ss'))
    }
} else {
    Save-LastKnownDate -Value $now
    Append-ValidDateHistory -Value $now
    Write-Log INFO ("Current date looks valid. Updated saved date to {0} and appended history." -f $now.ToString('yyyy-MM-dd HH:mm:ss'))
}

Write-Log INFO 'AutoTimeFix completed successfully.'
exit 0
