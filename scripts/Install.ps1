[CmdletBinding()]
param(
    [string]$NssmPath = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $root 'src\AutoTimeFixService.ps1'
if (-not (Test-Path $runner)) { throw "Project script not found: $runner" }
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw 'Run PowerShell as Administrator to install the AutoTimeFix service.' }

$serviceName = 'AutoTimeFix'
$ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$args = "-NoProfile -ExecutionPolicy Bypass -File `"$runner`""

if ([string]::IsNullOrWhiteSpace($NssmPath)) {
    $candidates = @(
        "$env:ProgramFiles\NSSM\win64\nssm.exe",
        "$env:ProgramFiles(x86)\NSSM\win64\nssm.exe",
        "$env:ProgramFiles\NSSM\win32\nssm.exe",
        "$env:ProgramFiles(x86)\NSSM\win32\nssm.exe",
        "$env:ProgramData\chocolatey\bin\nssm.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { $NssmPath = $candidate; break }
    }
}

if ([string]::IsNullOrWhiteSpace($NssmPath)) {
    $resolved = Get-Command nssm -ErrorAction SilentlyContinue
    if ($resolved) { $NssmPath = $resolved.Source }
}

if ([string]::IsNullOrWhiteSpace($NssmPath) -or -not (Test-Path -LiteralPath $NssmPath)) {
    throw 'NSSM was not found. Install NSSM first or pass -NssmPath to the nssm.exe file.'
}

$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service) {
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    & $NssmPath remove $serviceName confirm | Out-Null
}

& $NssmPath install $serviceName $ps $args | Out-Null
& $NssmPath set $serviceName AppDirectory $root | Out-Null
& $NssmPath set $serviceName ObjectName LocalSystem | Out-Null
& $NssmPath set $serviceName Start SERVICE_AUTO_START | Out-Null
& $NssmPath start $serviceName | Out-Null

$startupScript = Join-Path $PSScriptRoot 'NetTimeStartup.ps1'
& $ps -NoProfile -ExecutionPolicy Bypass -File $startupScript -Action Delay
if ($LASTEXITCODE -ne 0) { Write-Warning 'Could not set NetTime to Delayed Start. Check administrator permissions and the saved NetTime startup state.' }

Write-Host "Installed NSSM service '$serviceName'."
Write-Host "Script path: $runner"
Write-Host "Logs: $(Join-Path $root 'logs\AutoTimeFix.log')"
Write-Host "Test manually: powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$runner`" -Test"
