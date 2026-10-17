
# Repair-Clock - set the Windows clock from the internet without NetTime.
# NTP first, HTTPS Date header fallback. Does not use w32tm.
# HTTPS certificate validation stays enabled.

[CmdletBinding()]
param(
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $projectRoot 'logs'
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$Log = Join-Path $logDir 'Repair-Clock.log'

function Log($s) {
    Add-Content -LiteralPath $Log -Encoding UTF8 -Value (
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $s"
    )
}

# Elevate automatically because changing system time needs admin rights.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    $arg = '-NoProfile -ExecutionPolicy Bypass -File "' +
           $PSCommandPath + '"'
    if ($Test) { $arg += ' -Test' }
    try {
        Start-Process -FilePath 'powershell.exe' `
            -ArgumentList $arg -Verb RunAs
    } catch {
        Write-Host 'Can quyen Administrator de sua gio.' -ForegroundColor Red
        exit 2
    }
    exit 0
}

function Get-NtpUtc {
    $servers = @(
        'time.cloudflare.com',
        'time.google.com',
        'pool.ntp.org',
        'time.windows.com'
    )

    foreach ($server in $servers) {
        $udp = $null
        try {
            $udp = New-Object System.Net.Sockets.UdpClient
            $udp.Client.ReceiveTimeout = 2500
            $udp.Client.SendTimeout = 2500
            $udp.Connect($server, 123)

            $packet = New-Object byte[] 48
            $packet[0] = 0x1B
            [void]$udp.Send($packet, 48)

            $remote = New-Object System.Net.IPEndPoint(
                [System.Net.IPAddress]::Any, 0
            )
            $reply = $udp.Receive([ref]$remote)

            if ($reply.Length -lt 48) {
                throw 'NTP response too short'
            }

            $li = ($reply[0] -shr 6) -band 3
            $mode = $reply[0] -band 7
            $stratum = [int]$reply[1]

            if ($li -eq 3 -or $mode -ne 4 -or
                $stratum -lt 1 -or $stratum -gt 15) {
                throw 'Invalid or unsynchronized NTP server'
            }

            # Transmit timestamp seconds, network byte order
            [byte[]]$b = $reply[40..43]
            [array]::Reverse($b)
            [uint32]$sec = [BitConverter]::ToUInt32($b, 0)

            if ($sec -eq 0) { throw 'Empty NTP timestamp' }

            $unix = [long]$sec - 2208988800L
            $utc = [DateTimeOffset]::FromUnixTimeSeconds(
                $unix
            ).UtcDateTime

            # Reject obviously implausible dates.
            # Fixed reasonable window 2020-2045; review before 2046.
            if ($utc.Year -lt 2020 -or
   		$utc.Year -gt 2045) {
                throw "Implausible NTP date: $utc"
            }

            Log "NTP success: $server -> $utc UTC"
            return $utc
        }
        catch {
            Log "NTP failed: $server : $($_.Exception.Message)"
        }
        finally {
            if ($udp) { $udp.Close() }
        }
    }

    return $null
}

function Get-HttpsUtc {
    # HTTPS Date header; normal TLS certificate validation is retained.
    $urls = @(
        'https://www.google.com/generate_204',
        'https://www.microsoft.com/'
    )

    foreach ($url in $urls) {
        $req = $null
        $res = $null
        try {
            $req = [System.Net.HttpWebRequest]::Create($url)
            $req.Method = 'GET'
            $req.Timeout = 7000
            $req.ReadWriteTimeout = 7000
            $req.AllowAutoRedirect = $true
            $req.UserAgent = 'ClockRepair/1.0'

            $res = $req.GetResponse()
            $dateHeader = $res.Headers['Date']

            if ([string]::IsNullOrWhiteSpace($dateHeader)) {
                throw 'HTTPS response has no Date header'
            }

            $dto = [DateTimeOffset]::Parse(
                $dateHeader,
                [Globalization.CultureInfo]::InvariantCulture
            )
            $utc = $dto.UtcDateTime

            # shortcut: fixed 2024-2035 window, widen before the 2036 NTP era rollover
            if ($utc.Year -lt 2024 -or
    		$utc.Year -gt 2035) {
                throw "Implausible HTTPS date: $utc"
            }

            Log "HTTPS success: $url -> $utc UTC"
            return $utc
        }
        catch {
            Log "HTTPS failed: $url : $($_.Exception.Message)"
        }
        finally {
            if ($res) { $res.Close() }
        }
    }

    return $null
}

$exitCode = 1
$source = $null
try {
    Log '----- Start clock repair -----'
    Write-Host 'Dang tim gio chuan tren Internet...' -ForegroundColor Cyan

    $utc = $null

    # Retry NTP servers twice before HTTPS fallback
    for ($i = 1; $i -le 2 -and -not $utc; $i++) {
        $utc = Get-NtpUtc
        if ($utc) { $source = 'NTP' }
        elseif ($i -lt 2) { Start-Sleep -Seconds 2 }
    }

    if (-not $utc) {
        Write-Host 'NTP khong duoc. Dang thu HTTPS...'
        $utc = Get-HttpsUtc
        if ($utc) { $source = 'HTTPS' }
    }

    if (-not $utc) {
        throw 'Ca NTP va HTTPS deu that bai. Khong doi gio.'
    }

    # Set-Date uses local time; convert UTC using Windows time zone.
    $local = [DateTime]::SpecifyKind(
        $utc, [DateTimeKind]::Utc
    ).ToLocalTime()

    if ($Test) {
        Log "TEST OK: would set clock to $local (source: $source)"
        Write-Host ''
        Write-Host 'CHE DO THU: khong doi gio.' -ForegroundColor Yellow
        Write-Host "Gio lay duoc: $local (nguon: $source)"
        $exitCode = 0
    } else {
        Set-Date -Date $local | Out-Null

        Log "CLOCK SET OK: $local (source: $source)"
        Write-Host ''
        Write-Host 'DA SUA GIO THANH CONG!' -ForegroundColor Green
        Write-Host (Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
        Write-Host "Nguon gio: $source"
        $exitCode = 0
    }
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    Write-Host ''
    Write-Host 'CHUA SUA DUOC GIO!' -ForegroundColor Red
    Write-Host $_.Exception.Message
    Write-Host "Xem nhat ky: $Log"
    $exitCode = 1
}

exit $exitCode
