[CmdletBinding()]
param(
    [string]$NssmPath = '',
    [string]$ServiceName = 'winfakerct'
)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $root 'src\WinFakeRctService.ps1'

if (-not (Test-Path -LiteralPath $runner)) {
    throw "Project script not found: $runner"
}

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $admin) {
    throw 'Run PowerShell as Administrator to install the winfakerct service.'
}

if ([string]::IsNullOrWhiteSpace($NssmPath)) {
    $candidates = @(
        "$env:ProgramFiles\NSSM\win64\nssm.exe",
        "$env:ProgramFiles(x86)\NSSM\win64\nssm.exe",
        "$env:ProgramFiles\NSSM\win32\nssm.exe",
        "$env:ProgramFiles(x86)\NSSM\win32\nssm.exe",
        "$env:ProgramData\chocolatey\bin\nssm.exe",
        "C:\\Tools\\nssm\\win64\\nssm.exe",
        "C:\\Tools\\nssm\\win32\\nssm.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            $NssmPath = $candidate
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($NssmPath) -or -not (Test-Path -LiteralPath $NssmPath)) {
    throw 'NSSM was not found. Download NSSM and either place it on PATH or pass -NssmPath.'
}

$ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$args = "-NoProfile -ExecutionPolicy Bypass -File `"$runner`""

$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    & $NssmPath remove $ServiceName confirm | Out-Null
}

& $NssmPath install $ServiceName $ps $args | Out-Null
& $NssmPath set $ServiceName AppDirectory $root | Out-Null
& $NssmPath set $ServiceName ObjectName LocalSystem | Out-Null
& $NssmPath set $ServiceName Start SERVICE_AUTO_START | Out-Null
& $NssmPath start $ServiceName | Out-Null

$startupScript = Join-Path $PSScriptRoot 'NetTimeStartup.ps1'
& $ps -NoProfile -ExecutionPolicy Bypass -File $startupScript -Action Delay
if ($LASTEXITCODE -ne 0) { Write-Warning 'Could not set NetTime to Delayed Start. Check administrator permissions and the saved NetTime startup state.' }

Write-Host "Installed service '$ServiceName' using NSSM: $NssmPath"
Write-Host "Script: $runner"
Write-Host "Log: $(Join-Path $root 'logs\winfakerct.log')"
