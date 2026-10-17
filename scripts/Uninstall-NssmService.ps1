[CmdletBinding()]
param(
    [string]$NssmPath = '',
    [string]$ServiceName = 'winfakerct'
)
$ErrorActionPreference = 'Stop'
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

$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($service) {
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    if (-not [string]::IsNullOrWhiteSpace($NssmPath) -and (Test-Path -LiteralPath $NssmPath)) {
        & $NssmPath remove $ServiceName confirm | Out-Null
    } else {
        sc.exe delete $ServiceName | Out-Null
    }
    Write-Host "Removed service '$ServiceName'."
} else {
    Write-Host "Service '$ServiceName' was not found."
}
