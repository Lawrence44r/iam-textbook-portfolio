<#
.SYNOPSIS
    Script 12-5: SoD Gaming Pattern Detection
.DESCRIPTION
    Detects AI-assisted cumulative SoD gaming — sequential access requests that
    individually pass SoD checks but collectively constitute a conflict.

    Pattern: Attacker or insider requests conflicting entitlements over months,
    spacing requests to avoid automated detection. AI-assisted attackers can
    calculate optimal spacing to evade threshold-based controls.

    Detection signals:
    1. User holds entitlements across two conflicting SoD zones
    2. The requests were spaced suspiciously evenly (low standard deviation)
       — evenly-spaced requests suggest automation/AI coordination

.NOTES
    Chapter 12 §12.4 — AI-Assisted Attacks (SoD Gaming)
    Lab 12-D
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SoDZoneMatrixPath,   # CSV: Zone1,Zone2,Severity
    [Parameter(Mandatory)][string]$AccessRequestLogPath, # CSV: UserID,Entitlement,Zone,RequestDate,Status
    [int]$LookbackDays = 365,
    [double]$SuspiciousStdDevDays = 5.0,   # Low StdDev = suspiciously regular intervals
    [string]$OutputPath = ".\SoDGamingPatterns_$(Get-Date -Format 'yyyyMMdd').csv"
)

function Get-StdDev {
    param([double[]]$Values)
    if ($Values.Count -lt 2) { return [double]::MaxValue }
    $mean = ($Values | Measure-Object -Average).Average
    $variance = ($Values | ForEach-Object { [Math]::Pow($_ - $mean, 2) } | Measure-Object -Average).Average
    return [Math]::Sqrt($variance)
}

Write-Host "`n=== SoD Gaming Pattern Detection ===" -ForegroundColor Cyan
Write-Host "Lookback: $LookbackDays days | Suspicious StdDev threshold: $SuspiciousStdDevDays days`n"

# Load inputs
$sodZones   = Import-Csv $SoDZoneMatrixPath    # Zone1, Zone2, Severity
$requests   = Import-Csv $AccessRequestLogPath # UserID, Entitlement, Zone, RequestDate, Status

$cutoff     = (Get-Date).AddDays(-$LookbackDays)
$recentReqs = $requests | Where-Object {
    $_.Status -eq 'Approved' -and
    ([datetime]::Parse($_.RequestDate)) -ge $cutoff
}

# Build user → {Zone → [requests]} map
$userZoneMap = @{}
foreach ($req in $recentReqs) {
    $uid = $req.UserID
    if (-not $userZoneMap.ContainsKey($uid)) { $userZoneMap[$uid] = @{} }
    if (-not $userZoneMap[$uid].ContainsKey($req.Zone)) { $userZoneMap[$uid][$req.Zone] = @() }
    $userZoneMap[$uid][$req.Zone] += $req
}

$findings = @()

foreach ($userId in $userZoneMap.Keys) {
    $zones = $userZoneMap[$userId]

    foreach ($rule in $sodZones) {
        $zone1 = $rule.Zone1
        $zone2 = $rule.Zone2

        # Check if user has entitlements in BOTH conflicting zones
        if (-not ($zones.ContainsKey($zone1) -and $zones.ContainsKey($zone2))) { continue }

        $zone1Reqs = $zones[$zone1]
        $zone2Reqs = $zones[$zone2]

        # All requests combined, sorted by date
        $allReqs = (@($zone1Reqs) + @($zone2Reqs)) | Sort-Object { [datetime]::Parse($_.RequestDate) }

        # Calculate intervals between consecutive requests
        $dates     = $allReqs | ForEach-Object { [datetime]::Parse($_.RequestDate) }
        $intervals = @()
        for ($i = 1; $i -lt $dates.Count; $i++) {
            $intervals += ($dates[$i] - $dates[$i-1]).TotalDays
        }

        $stdDev = Get-StdDev -Values $intervals
        $avgInterval = if ($intervals.Count -gt 0) { ($intervals | Measure-Object -Average).Average } else { 0 }

        $isSuspiciouslyRegular = ($intervals.Count -ge 2) -and ($stdDev -lt $SuspiciousStdDevDays)

        $color = if ($isSuspiciouslyRegular) { 'Red' } else { 'Yellow' }
        Write-Host "[$($rule.Severity)] $userId`: $zone1 + $zone2 conflict" -ForegroundColor $color
        Write-Host "  Zone 1 entitlements: $(($zone1Reqs | ForEach-Object {$_.Entitlement}) -join ', ')"
        Write-Host "  Zone 2 entitlements: $(($zone2Reqs | ForEach-Object {$_.Entitlement}) -join ', ')"
        Write-Host "  Request intervals: avg=$([math]::Round($avgInterval,1))d, stddev=$([math]::Round($stdDev,1))d"
        if ($isSuspiciouslyRegular) {
            Write-Host "  [AI GAMING SUSPECTED] Regular spacing (StdDev=$([math]::Round($stdDev,1))d < threshold $SuspiciousStdDevDays d) suggests automated coordination" -ForegroundColor Red
        }

        $findings += [PSCustomObject]@{
            UserID                  = $userId
            ConflictZone1           = $zone1
            ConflictZone2           = $zone2
            Severity                = $rule.Severity
            Zone1Entitlements       = ($zone1Reqs | ForEach-Object {$_.Entitlement}) -join '; '
            Zone2Entitlements       = ($zone2Reqs | ForEach-Object {$_.Entitlement}) -join '; '
            RequestCount            = $allReqs.Count
            AvgIntervalDays         = [math]::Round($avgInterval, 1)
            StdDevIntervalDays      = [math]::Round($stdDev, 1)
            SuspiciouslyRegular     = $isSuspiciouslyRegular
            AISuspected             = $isSuspiciouslyRegular
            FirstRequest            = $dates[0].ToString('yyyy-MM-dd')
            LastRequest             = $dates[-1].ToString('yyyy-MM-dd')
        }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Users analyzed:         $($userZoneMap.Count)"
Write-Host "SoD zone conflicts:     $($findings.Count)"
Write-Host "AI gaming suspected:    $(($findings | Where-Object {$_.AISuspected}).Count)"

if ($findings.Count -gt 0) {
    $findings | Sort-Object AISuspected, Severity -Descending | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-Host "`nExported: $OutputPath" -ForegroundColor Green
    Write-Host "`nRemediation: Revoke one entitlement from each conflicting zone. Investigate AI-suspected cases with HR and Legal." -ForegroundColor Yellow
} else {
    Write-Host "[CLEAN] No SoD gaming patterns detected in the lookback period." -ForegroundColor Green
}
