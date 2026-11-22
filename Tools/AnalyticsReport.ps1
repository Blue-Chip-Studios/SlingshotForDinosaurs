<#
    AnalyticsReport.ps1
    -------------------
    Pulls the game's key metrics from the Open Cloud Analytics Query API and
    writes a Markdown report to Docs/Analytics/Report-<date>.md.

    Usage (from the repo root):
        powershell -NoProfile -ExecutionPolicy Bypass -File Tools/AnalyticsReport.ps1 [-Days 14]

    Needs ROBLOX_API_KEY in .env with the universe-analytics (universe.analytics:read)
    permission. The key is read here only and never printed.
    Metric names: https://create.roblox.com/docs/cloud/guides/analytics/metrics
#>
param([int]$Days = 14)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Universe = 10778444607
$KeyLine = Get-Content (Join-Path $Root '.env') | Where-Object { $_ -match '^\s*ROBLOX_API_KEY\s*=' } | Select-Object -First 1
$Key = ($KeyLine -replace '^\s*ROBLOX_API_KEY\s*=\s*', '').Trim().Trim('"')
$Headers = @{ 'x-api-key' = $Key }
$Base = 'https://apis.roblox.com/analytics-query-api'

$End = (Get-Date).ToUniversalTime().Date
$Start = $End.AddDays(-$Days)
$StartS = $Start.ToString('yyyy-MM-ddT00:00:00Z')
$EndS = $End.ToString('yyyy-MM-ddT00:00:00Z')

function Query($Body) {
    $Body.startTime = $StartS
    $Body.endTime = $EndS
    $Json = $Body | ConvertTo-Json -Depth 6 -Compress
    # The API rate-limits bursts (429 / empty error): pace queries and retry with backoff.
    for ($Try = 1; $Try -le 5; $Try++) {
        Start-Sleep -Milliseconds 700
        $Res = QueryOnce $Json
        if (-not $Res.Retry) { return $Res }
        Start-Sleep -Seconds (4 * $Try)
    }
    return @{ Error = 'Rate limited; try again in a minute.' }
}

function QueryOnce($Json) {
    try {
        $R = Invoke-RestMethod -Method Post -Uri "$Base/v1/universes/$Universe/metrics" -Headers $Headers -ContentType 'application/json' -Body $Json
        for ($i = 0; -not $R.done -and $i -lt 30; $i++) {
            Start-Sleep -Seconds 2
            $R = Invoke-RestMethod -Method Get -Uri "$Base/$($R.path)" -Headers $Headers
        }
        if ($R.error) { return @{ Error = $R.error.message } }
        return @{ Values = $R.response.values }
    } catch {
        $Msg = $_.Exception.Message
        try {
            $Raw = $_.ErrorDetails.Message
            if (-not $Raw -and $_.Exception.Response) {
                $Raw = (New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd()
            }
            $J = $Raw | ConvertFrom-Json
            if ($J.error.message) { $Msg = $J.error.message } elseif ($J.message) { $Msg = $J.message } elseif ($Raw) { $Msg = $Raw }
        } catch {}
        $Code = 0
        try { $Code = [int]$_.Exception.Response.StatusCode } catch {}
        if ($Code -eq 429 -or $Code -ge 500 -or $Msg -match '"message":""') { return @{ Retry = $true } }
        return @{ Error = $Msg }
    }
}

function Fmt($v, $Kind) {
    if ($null -eq $v) { return '-' }
    switch ($Kind) {
        'pct' { return ('{0:N1}%' -f ([double]$v * $(if ([double]$v -le 1) { 100 } else { 1 }))) }
        'num' { return ('{0:N0}' -f [double]$v) }
        default { return ('{0:N2}' -f [double]$v) }
    }
}

# --- Daily table -----------------------------------------------------------------
$Daily = [ordered]@{
    'DAU'               = @('DailyActiveUsers', 'num')
    'Playtime/DAU (min)'= @('AveragePlayTimeMinutesPerDAU', 'dec')
    'Session (min)'     = @('AverageSessionLengthMinutes', 'dec')
    'D1 ret.'           = @('ForwardD1Retention', 'pct')
    'D7 ret.'           = @('ForwardD7Retention', 'pct')
    'Revenue (R$)'      = @('DailyRevenue', 'num')
    'Payer CVR'         = @('PayingUsersCVR', 'pct')
    'ARPDAU'            = @('AverageRevenuePerUser', 'dec')
    'Ad spend ($)'      = @('SponsoredAdsSpendUsd', 'dec')
    'Ad clicks'         = @('SponsoredAdsClicks', 'num')
}
$Table = @{}
$Errors = @()
foreach ($Name in $Daily.Keys) {
    $R = Query @{ metric = $Daily[$Name][0]; granularity = 'OneDay' }
    if ($R.Error) { $Errors += "- $Name ($($Daily[$Name][0])): $($R.Error)"; continue }
    foreach ($P in $R.Values[0].dataPoints) {
        $D = ([datetime]$P.time).ToUniversalTime().ToString('yyyy-MM-dd')
        if (-not $Table[$D]) { $Table[$D] = @{} }
        $Table[$D][$Name] = $P.value
    }
}

$Out = New-Object System.Collections.Generic.List[string]
$Out.Add("# Slingshot For Dinosaurs: analytics report")
$Out.Add("")
$Out.Add("Range: $($Start.ToString('yyyy-MM-dd')) to $($End.AddDays(-1).ToString('yyyy-MM-dd')) (UTC). Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm').")
$Out.Add("Targets: see Docs/UPDATE_PLAN.md (KPI targets).")
$Out.Add("")
$Out.Add("## Daily")
$Out.Add("")
$Out.Add("| Date | " + (($Daily.Keys) -join ' | ') + " |")
$Out.Add("|---" * ($Daily.Count + 1) + "|")
foreach ($D in ($Table.Keys | Sort-Object)) {
    $Cells = foreach ($Name in $Daily.Keys) { Fmt $Table[$D][$Name] $Daily[$Name][1] }
    $Out.Add("| $D | " + ($Cells -join ' | ') + " |")
}

# --- Breakdowns over the whole range -----------------------------------------------
function Section($Title, $Body, $Kind, $Note) {
    $Out.Add("")
    $Out.Add("## $Title")
    if ($Note) { $Out.Add(""); $Out.Add($Note) }
    $Out.Add("")
    $R = Query $Body
    if ($R.Error) { $Out.Add("_Not available: $($R.Error)_"); return }
    if (-not $R.Values -or $R.Values.Count -eq 0) { $Out.Add("_No data yet._"); return }
    $Out.Add("| Segment | Value |")
    $Out.Add("|---|---|")
    foreach ($V in $R.Values) {
        $Label = ($V.breakdowns | ForEach-Object { if ($_.displayValue) { $_.displayValue } else { $_.value } }) -join ' / '
        $Pts = @($V.dataPoints | Where-Object { $null -ne $_.value })
        $Val = if ($Pts.Count -gt 0) { ($Pts | Measure-Object -Property value -Average).Average } else { $null }
        $Out.Add("| $Label | $(Fmt $Val $Kind) |")
    }
}

Section 'D1 retention by acquisition source' @{ metric = 'ForwardD1Retention'; granularity = 'OneDay'; breakdown = @('AcquisitionSource') } 'pct' 'Average over the range. Sponsored ads vs home/search/friends; compare against ad spend above.'
Section 'D1 retention by platform' @{ metric = 'ForwardD1Retention'; granularity = 'OneDay'; breakdown = @('Platform') } 'pct'
Section 'Onboarding funnel (step completion)' @{ metric = 'FunnelStepCompletionRate'; granularity = 'None'; breakdown = @('FunnelStep'); filter = @(@{ dimension = 'FunnelName'; values = @('Onboarding'); operation = 'In' }) } 'pct' 'Where new players drop: Joined > FirstCharge > FirstLaunch > FirstBounce > FirstCatch > FirstPlacement > FirstTrain > FirstUpgrade.'
Section 'Purchase funnel (Prompted to Succeeded)' @{ metric = 'FunnelStepCompletionRate'; granularity = 'None'; breakdown = @('FunnelStep'); filter = @(@{ dimension = 'FunnelName'; values = @('Purchase'); operation = 'In' }) } 'pct'
Section 'Revenue by product' @{ metric = 'ItemMonetizationRevenue'; granularity = 'None'; breakdown = @('ProductKey') } 'num'
# Custom events: CustomEventName is filter-only, so query each event from Config/AnalyticsConfig.
$Out.Add("")
$Out.Add("## Custom events (players / count)")
$Out.Add("")
$Out.Add("| Event | Players | Count |")
$Out.Add("|---|---|---|")
$Cfg = Get-Content (Join-Path $Root 'Config/AnalyticsConfig.luau') -Raw
$InCustom = [regex]::Match($Cfg, 'Custom = \{([^}]*)\}').Groups[1].Value
$Names = [regex]::Matches($InCustom, '(\w+) = true') | ForEach-Object { $_.Groups[1].Value }
foreach ($N in $Names) {
    $F = @(@{ dimension = 'CustomEventName'; values = @($N); operation = 'In' })
    $U = Query @{ metric = 'CustomEventCountUser'; granularity = 'None'; filter = $F }
    $C = Query @{ metric = 'CustomEventCount'; granularity = 'None'; filter = $F }
    $UV = @($U.Values | ForEach-Object { $_.dataPoints } | ForEach-Object { $_.value }) | Select-Object -First 1
    $CV = @($C.Values | ForEach-Object { $_.dataPoints } | ForEach-Object { $_.value }) | Select-Object -First 1
    $Out.Add("| $N | $(Fmt $UV 'num') | $(Fmt $CV 'num') |")
}
Section 'Avg session minutes by join source (SessionEnd)' @{ metric = 'CustomEventAvgValue'; granularity = 'None'; breakdown = @('CustomField1'); filter = @(@{ dimension = 'CustomEventName'; values = @('SessionEnd'); operation = 'In' }) } 'dec' 'Join source from launchData links (src:tiktok:...), invites, notifications or Roblox (home/search/ads).'
Section 'Session length buckets (SessionEnd)' @{ metric = 'CustomEventCount'; granularity = 'None'; breakdown = @('CustomField3'); filter = @(@{ dimension = 'CustomEventName'; values = @('SessionEnd'); operation = 'In' }) } 'num'
Section 'Ad spend by campaign ($)' @{ metric = 'SponsoredAdsSpendUsd'; granularity = 'None'; breakdown = @('CampaignId') } 'dec'

if ($Errors.Count -gt 0) {
    $Out.Add("")
    $Out.Add("## Metrics that could not be read")
    $Out.Add("")
    $Errors | ForEach-Object { $Out.Add($_) }
}

$Dir = Join-Path $Root 'Docs/Analytics'
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$File = Join-Path $Dir ("Report-" + (Get-Date -Format 'yyyy-MM-dd') + ".md")
$Out | Out-File -FilePath $File -Encoding utf8
Write-Output "Wrote $File"
