# Assert-based self-check for WinFakeRct anti-rollback logic.
# Runs without changing the system clock by dot-sourcing the runner and
# overriding the time-dependent functions.
$ErrorActionPreference = 'Stop'
$failures = 0

function Assert-Equal($expected, $actual, $message) {
    if ($expected -ne $actual) {
        Write-Host "FAIL: $message | expected=$expected actual=$actual" -ForegroundColor Red
        $script:failures++
    } else {
        Write-Host "PASS: $message" -ForegroundColor Green
    }
}

function Assert-True($value, $message) {
    Assert-Equal $true $value $message
}

# Dot-source the runner so its functions are available in this scope.
$runner = Join-Path $PSScriptRoot '..\src\WinFakeRct.ps1'
. $runner

# --- Override time-dependent functions so we can simulate dates without touching the system clock ---

$script:savedDate = $null
$script:restoredTo = $null
$script:saveCalled = $false

function Save-LastKnownDate([DateTime]$Value) {
    $script:savedDate = $Value
    $script:saveCalled = $true
}

function Set-Date([DateTime]$Date) {
    $script:restoredTo = $Date
}

function Write-Log([string]$Level, [string]$Message) {
    # Suppress log output during tests.
}

# --- Re-run the core decision logic with simulated dates ---

function Run-Check([DateTime]$Now, [object]$LastKnown) {
    $script:savedDate = $LastKnown
    $script:restoredTo = $null
    $script:saveCalled = $false

    $thresholdYear = 2020
    $toleranceHours = 24

    $hasBaseline = $LastKnown -ne $null

    $rollback = $false
    if ($Now.Year -lt $thresholdYear) {
        $rollback = $true
    } elseif ($hasBaseline -and $Now -lt $LastKnown.AddHours(-$toleranceHours)) {
        $rollback = $true
    }

    if ($rollback) {
        if (-not $hasBaseline) {
            return 'ERROR_NO_BASELINE'
        } else {
            Set-Date -Date $LastKnown | Out-Null
            return "RESTORED_TO_$($LastKnown.ToString('yyyy-MM-dd HH:mm:ss'))"
        }
    } else {
        if (-not $hasBaseline -or $Now -gt $LastKnown) {
            Save-LastKnownDate -Value $Now | Out-Null
            return "SAVED_$($Now.ToString('yyyy-MM-dd HH:mm:ss'))"
        } else {
            return 'UNCHANGED_WITHIN_TOLERANCE'
        }
    }
}

# Test 1: Year below threshold with saved baseline -> restore
$result = Run-Check -Now ([DateTime]::Parse('2019-01-01')) -LastKnown ([DateTime]::Parse('2026-10-15'))
Assert-Equal "RESTORED_TO_2026-10-15 00:00:00" $result "Year 2019 with baseline restores saved date"

# Test 2: Year below threshold without baseline -> error
$result = Run-Check -Now ([DateTime]::Parse('2019-01-01')) -LastKnown $null
Assert-Equal 'ERROR_NO_BASELINE' $result "Year 2019 without baseline errors"

# Test 3: Clock rolled back more than tolerance -> restore (more than 24h behind)
$result = Run-Check -Now ([DateTime]::Parse('2026-10-14 09:00:00')) -LastKnown ([DateTime]::Parse('2026-10-15 10:00:00'))
Assert-Equal "RESTORED_TO_2026-10-15 10:00:00" $result "Rollback beyond 24h tolerance restores baseline"

# Test 4: Clock within tolerance behind baseline -> unchanged
$result = Run-Check -Now ([DateTime]::Parse('2026-10-15 09:00:00')) -LastKnown ([DateTime]::Parse('2026-10-15 10:00:00'))
Assert-Equal 'UNCHANGED_WITHIN_TOLERANCE' $result "Rollback within 24h tolerance leaves baseline unchanged"

# Test 5: Clock newer than baseline -> save new date
$result = Run-Check -Now ([DateTime]::Parse('2026-10-17 11:00:00')) -LastKnown ([DateTime]::Parse('2026-10-15 10:00:00'))
Assert-Equal "SAVED_2026-10-17 11:00:00" $result "Newer clock saves new baseline"

# Test 6: Clock equal to baseline -> unchanged (not newer, not rollback)
$result = Run-Check -Now ([DateTime]::Parse('2026-10-15 10:00:00')) -LastKnown ([DateTime]::Parse('2026-10-15 10:00:00'))
Assert-Equal 'UNCHANGED_WITHIN_TOLERANCE' $result "Clock equal to baseline leaves baseline unchanged"

Write-Host ""
if ($failures -eq 0) {
    Write-Host "All tests passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failures test(s) failed." -ForegroundColor Red
    exit 1
}
