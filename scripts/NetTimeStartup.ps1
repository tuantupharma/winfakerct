[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Delay', 'Restore', 'Inspect')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $projectRoot 'logs'
$stateFile = Join-Path $logDir 'NetTimeStartupState.json'

function Find-NetTimeService([string]$Name = '') {
    if ($Name) {
        $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
        return $service
    }

    $matches = @(Get-CimInstance -ClassName Win32_Service | Where-Object {
        $_.Name -match '(?i)NetTime' -or $_.DisplayName -match '(?i)NetTime'
    })
    if ($matches.Count -gt 1) {
        throw "Found multiple NetTime services: $($matches.Name -join ', '). No service was changed."
    }
    if ($matches.Count -eq 0) { return $null }
    return $matches[0]
}

function Get-RegistryValue([string]$Path, [string]$Name) {
    $property = (Get-ItemProperty -LiteralPath $Path -ErrorAction Stop).PSObject.Properties[$Name]
    if ($null -eq $property) {
        return [pscustomobject]@{ Exists = $false; Value = $null }
    }
    return [pscustomobject]@{ Exists = $true; Value = [int]$property.Value }
}

function Set-DelayedAutoStart([string]$Name) {
    & "$env:SystemRoot\System32\sc.exe" config $Name 'start= delayed-auto' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not set '$Name' to delayed automatic start (sc.exe exit code $LASTEXITCODE)." }
}

function Restore-Startup([object]$State) {
    $service = Find-NetTimeService -Name $State.ServiceName
    if (-not $service) { throw "Saved NetTime service '$($State.ServiceName)' was not found; saved startup state was kept." }

    if (-not $State.StartExists) { throw 'Saved NetTime startup state has no Start value; it was kept for manual recovery.' }
    $startType = switch ([int]$State.StartValue) {
        0 { 'boot' }
        1 { 'system' }
        2 { if ($State.DelayedAutoStartExists -and [int]$State.DelayedAutoStartValue -eq 1) { 'delayed-auto' } else { 'auto' } }
        3 { 'demand' }
        4 { 'disabled' }
        default { throw "Unsupported saved NetTime Start value '$($State.StartValue)'; saved state was kept." }
    }

    & "$env:SystemRoot\System32\sc.exe" config $service.Name "start= $startType" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not restore '$($service.Name)' startup type (sc.exe exit code $LASTEXITCODE)." }

    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($service.Name)"
    if ($State.DelayedAutoStartExists) {
        New-ItemProperty -LiteralPath $registryPath -Name DelayedAutoStart -PropertyType DWord -Value ([int]$State.DelayedAutoStartValue) -Force | Out-Null
    } else {
        Remove-ItemProperty -LiteralPath $registryPath -Name DelayedAutoStart -ErrorAction SilentlyContinue
    }

    Remove-Item -LiteralPath $stateFile -Force
    Write-Host "Restored NetTime service '$($service.Name)' startup configuration."
}

try {
    if ($Action -eq 'Restore') {
        if (-not (Test-Path -LiteralPath $stateFile)) {
            Write-Host 'No saved NetTime startup configuration; nothing to restore.'
        } else {
            $savedState = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
            Restore-Startup -State $savedState
        }
        exit 0
    }

    if ($Action -eq 'Delay' -and (Test-Path -LiteralPath $stateFile)) {
        $savedState = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        $service = Find-NetTimeService -Name $savedState.ServiceName
        if (-not $service) { throw "Saved NetTime service '$($savedState.ServiceName)' was not found; no service was changed." }
    } else {
        $service = Find-NetTimeService
    }

    if (-not $service) {
        Write-Warning 'No NetTime Windows service was found; startup configuration was not changed.'
        exit 0
    }

    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($service.Name)"
    $start = Get-RegistryValue -Path $registryPath -Name Start
    $delayed = Get-RegistryValue -Path $registryPath -Name DelayedAutoStart

    if ($Action -eq 'Inspect') {
        [pscustomobject]@{
            ServiceName = $service.Name
            DisplayName = $service.DisplayName
            State = $service.State
            Start = $start.Value
            DelayedAutoStart = if ($delayed.Exists) { $delayed.Value } else { $null }
            SnapshotExists = Test-Path -LiteralPath $stateFile
        }
        exit 0
    }

    if ($start.Value -ne 2) {
        Write-Warning "NetTime service '$($service.Name)' is not configured for automatic start; left unchanged."
        exit 0
    }

    if (-not (Test-Path -LiteralPath $stateFile)) {
        if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        [pscustomobject]@{
            ServiceName = $service.Name
            StartExists = $start.Exists
            StartValue = $start.Value
            DelayedAutoStartExists = $delayed.Exists
            DelayedAutoStartValue = $delayed.Value
        } | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
    }

    Set-DelayedAutoStart -Name $service.Name
    Write-Host "Set NetTime service '$($service.Name)' to Automatic (Delayed Start). This takes effect on the next Windows startup."
} catch {
    Write-Error $_
    exit 1
}