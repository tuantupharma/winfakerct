[CmdletBinding()]
param(
    [string]$NssmPath = ''
)
$ErrorActionPreference='Stop'
$serviceName='AutoTimeFix'
$ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$startupScript = Join-Path $PSScriptRoot 'NetTimeStartup.ps1'
& $ps -NoProfile -ExecutionPolicy Bypass -File $startupScript -Action Restore
if ($LASTEXITCODE -ne 0) { Write-Warning 'Could not restore NetTime startup configuration. The saved state was kept for manual recovery.' }

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

$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service) {
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    if (-not [string]::IsNullOrWhiteSpace($NssmPath) -and (Test-Path -LiteralPath $NssmPath)) {
        & $NssmPath remove $serviceName confirm | Out-Null
    } else {
        sc.exe delete $serviceName | Out-Null
    }
    Write-Host "Removed NSSM service '$serviceName'."
} else {
    Write-Host "NSSM service '$serviceName' was not found."
}

Write-Host 'Project files and logs were not deleted.'
