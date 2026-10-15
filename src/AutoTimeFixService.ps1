$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $PSScriptRoot 'AutoTimeFix.ps1'
$logDir = Join-Path $projectRoot 'logs'
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir 'AutoTimeFix.log'
$scheduleFile = Join-Path $logDir 'AutoTimeFix.NextRun.txt'
$successInterval = [TimeSpan]::FromDays(1)
$retryInterval = [TimeSpan]::FromHours(4)
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Write-ServiceLog([string]$Level, [string]$Message) {
    $line = '{0} [{1}] {2}' -f [DateTimeOffset]::Now.ToString('yyyy-MM-dd HH:mm:ss zzz'), $Level, $Message
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}

function Get-NextRun {
    if (-not (Test-Path -LiteralPath $scheduleFile)) { return [DateTimeOffset]::MinValue }
    try {
        return [DateTimeOffset]::Parse((Get-Content -LiteralPath $scheduleFile -Raw).Trim())
    } catch {
        Write-ServiceLog WARN "Could not read saved schedule; running now. $($_.Exception.Message)"
        return [DateTimeOffset]::MinValue
    }
}

function Save-NextRun([DateTimeOffset]$Value) {
    $Value.ToString('o') | Set-Content -LiteralPath $scheduleFile -Encoding UTF8
}

while ($true) {
    $nextRun = Get-NextRun
    $remaining = $nextRun - [DateTimeOffset]::UtcNow
    if ($remaining.TotalSeconds -gt 0) {
        Start-Sleep -Seconds ([Math]::Min(60, [Math]::Max(1, [int][Math]::Ceiling($remaining.TotalSeconds))))
        continue
    }

    $exitCode = 1
    try {
        Write-ServiceLog INFO 'Starting scheduled AutoTimeFix run.'
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$runner`""
        $process = Start-Process -FilePath $powershell -ArgumentList $arguments -PassThru -Wait -WindowStyle Hidden
        $exitCode = $process.ExitCode
    } catch {
        Write-ServiceLog ERROR "Could not run AutoTimeFix: $($_.Exception.Message)"
    }

    if ($exitCode -eq 0) {
        $nextRun = [DateTimeOffset]::UtcNow.Add($successInterval)
        Write-ServiceLog INFO "Run succeeded; next run is $($nextRun.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss zzz'))."
    } else {
        $nextRun = [DateTimeOffset]::UtcNow.Add($retryInterval)
        Write-ServiceLog ERROR "Run failed with exit code $exitCode; retry scheduled for $($nextRun.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss zzz'))."
    }
    Save-NextRun -Value $nextRun
}