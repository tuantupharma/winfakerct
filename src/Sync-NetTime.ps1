function Find-NetTime {
    [CmdletBinding()]
    param([string]$HintPath)
    $candidates = @()
    if ($HintPath) { $candidates += $HintPath }
    $candidates += @(
        "$env:ProgramFiles\NetTime\NetTime.exe",
        "${env:ProgramFiles(x86)}\NetTime\NetTime.exe",
        "$env:ProgramW6432\NetTime\NetTime.exe"
    )
    foreach ($key in @(
        'HKLM:\SOFTWARE\Subjective Software\NetTime',
        'HKLM:\SOFTWARE\WOW6432Node\Subjective Software\NetTime'
    )) {
        try {
            $p = Get-ItemProperty -Path $key -ErrorAction Stop
            foreach ($name in @('InstallDir','InstallPath','Path')) {
                if ($p.$name) { $candidates += (Join-Path $p.$name 'NetTime.exe') }
            }
        } catch {}
    }
    foreach ($path in ($candidates | Select-Object -Unique)) {
        if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
            return (Get-Item -LiteralPath $path)
        }
    }
    # Limited search in common roots; avoids an expensive whole-disk scan.
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($base -and (Test-Path $base)) {
            $found = Get-ChildItem -LiteralPath $base -Filter NetTime.exe -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { return $found }
        }
    }
    return $null
}

function Invoke-NetTimeSync {
    [CmdletBinding()]
    param(
        [string]$HintPath,
        [int]$WaitSeconds = 45,
        [switch]$WhatIfOnly
    )
    $file = Find-NetTime -HintPath $HintPath
    if (-not $file) { throw 'NetTime.exe was not found. Set NetTimePath in config.json or install NetTime.' }
    $version = $file.VersionInfo.FileVersion
    if ($WhatIfOnly) {
        return [pscustomobject]@{ Path=$file.FullName; Version=$version; Started=$false; Note='Dry run: no process launched.' }
    }
    # /updateonce is documented by the NetTime project for one synchronization then exit.
    # Do not try undocumented alternatives or silently fall back to launching a persistent UI.
    $proc = Start-Process -FilePath $file.FullName -ArgumentList '/updateonce' -PassThru
    if (-not $proc.WaitForExit($WaitSeconds * 1000)) {
        try { $proc.Refresh() } catch {}
        throw "NetTime did not exit within $WaitSeconds seconds (version '$version'). Check NetTime's own log; no success is assumed."
    }
    if ($proc.ExitCode -ne 0) { throw "NetTime exited with code $($proc.ExitCode) (version '$version')." }
    [pscustomobject]@{ Path=$file.FullName; Version=$version; Started=$true; ExitCode=$proc.ExitCode; Note='Process exited; clock accuracy must still be independently checked.' }
}
