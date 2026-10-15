# Returns a corroborated UTC estimate from independent HTTPS Date headers.
# Windows PowerShell 5.1 compatible.
function Get-NetworkTime {
    [CmdletBinding()]
    param(
        [string[]]$Uri = @(
            'https://www.microsoft.com/',
            'https://www.cloudflare.com/',
            'https://www.google.com/generate_204'
        ),
        [int]$MaxDisagreementSeconds = 120,
        [int]$TimeoutSeconds = 8
    )
    $samples = @()
    foreach ($u in $Uri) {
        try {
            $start = [DateTime]::UtcNow
            $response = Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec $TimeoutSeconds -MaximumRedirection 3 -ErrorAction Stop
            $end = [DateTime]::UtcNow
            $dateHeader = $response.Headers['Date']
            if (-not $dateHeader) { continue }
            $parsed = [DateTimeOffset]::MinValue
            if (-not [DateTimeOffset]::TryParse([string]$dateHeader, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsed)) { continue }
            # Date header has one-second precision; use request midpoint to reduce latency bias.
            $midpoint = $start.AddTicks([long](($end - $start).Ticks / 2))
            $estimate = $parsed.UtcDateTime.AddTicks(($midpoint - $end).Ticks)
            $samples += [pscustomobject]@{ Uri=$u; Utc=$estimate; Header=$dateHeader; LatencyMs=[int](($end-$start).TotalMilliseconds) }
        } catch {
            Write-Verbose ("Time source failed {0}: {1}" -f $u, $_.Exception.Message)
        }
    }
    if ($samples.Count -lt 2) { throw "Not enough independent HTTPS Date samples (need at least 2; got $($samples.Count))." }
    $sorted = @($samples | Sort-Object Utc)
    $middle = [int][Math]::Floor($sorted.Count / 2)
    if (($sorted[-1].Utc - $sorted[0].Utc).TotalSeconds -gt $MaxDisagreementSeconds) {
        throw "Internet time sources disagree by more than $MaxDisagreementSeconds seconds; refusing to change the clock."
    }
    if (($sorted.Count % 2) -eq 1) { $chosen = $sorted[$middle].Utc }
    else { $chosen = $sorted[$middle-1].Utc.AddTicks([long](($sorted[$middle].Utc - $sorted[$middle-1].Utc).Ticks / 2)) }
    [pscustomobject]@{
        Utc = $chosen
        Sources = @($samples | ForEach-Object { $_.Uri })
        SampleCount = $samples.Count
        SpreadSeconds = [Math]::Round(($sorted[-1].Utc - $sorted[0].Utc).TotalSeconds, 2)
        Samples = $samples
    }
}
