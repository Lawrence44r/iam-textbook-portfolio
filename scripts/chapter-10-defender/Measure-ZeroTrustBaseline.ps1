<#
.SYNOPSIS
    Script 10-5: Zero Trust Baseline Assessment
.DESCRIPTION
    Measures current ZT maturity across all pillars; exports JSON for trend tracking.
    Run monthly to show maturity progress over time.
.NOTES
    Requires: Microsoft.Graph module
    Permissions: User.Read.All, Policy.Read.All, Directory.Read.All,
                 IdentityRiskEvent.Read.All, DeviceManagementConfiguration.Read.All
    Chapter 10 §10.8 — 18-Month ZT Implementation Runbook
#>
[CmdletBinding()]
param(
    [string]$OutputDir = "."
)

Import-Module Microsoft.Graph.Users             -ErrorAction Stop
Import-Module Microsoft.Graph.Identity.SignIns  -ErrorAction Stop
Import-Module Microsoft.Graph.Reports           -ErrorAction Stop

try { Get-MgContext -ErrorAction Stop | Out-Null } catch {
    Connect-MgGraph -Scopes "User.Read.All","Policy.Read.All","Directory.Read.All",
                             "IdentityRiskEvent.Read.All","AuditLog.Read.All","Reports.Read.All"
}

$date    = Get-Date
$outFile = "$OutputDir\ZT_Baseline_$($date.ToString('yyyyMMdd')).json"
$metrics = @{}
$scores  = @{}

Write-Host "`n=== Zero Trust Baseline Assessment ===" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# --- Identity Metrics ---
Write-Host "[1] IDENTITY" -ForegroundColor Yellow

# MFA Registration %
try {
    $mfaReport = Get-MgReportAuthenticationMethodUserRegistrationDetail -All
    $total     = $mfaReport.Count
    $mfaReg    = ($mfaReport | Where-Object { $_.IsMfaRegistered }).Count
    $mfaPct    = if ($total -gt 0) { [math]::Round(($mfaReg / $total) * 100, 1) } else { 0 }
    Write-Host "  MFA registered: $mfaReg/$total ($mfaPct%)"

    $phishing  = ($mfaReport | Where-Object { $_.IsPasswordlessCapable }).Count
    $phishPct  = if ($total -gt 0) { [math]::Round(($phishing / $total) * 100, 1) } else { 0 }
    Write-Host "  Phishing-resistant (passwordless capable): $phishing/$total ($phishPct%)"

    $metrics.MFARegistrationPct    = $mfaPct
    $metrics.PhishingResistantPct  = $phishPct
    $scores.MFA = if ($mfaPct -ge 95) { 2 } elseif ($mfaPct -ge 80) { 1 } else { 0 }
} catch {
    Write-Host "  [SKIP] MFA report: $_" -ForegroundColor Gray
}

# Global Admin count
try {
    $globalAdmins = Get-MgDirectoryRoleMember -DirectoryRoleId (
        Get-MgDirectoryRole -Filter "displayName eq 'Global Administrator'"
    ).Id -All
    Write-Host "  Global Administrators: $($globalAdmins.Count) (target: ≤ 5)"
    $metrics.GlobalAdminCount = $globalAdmins.Count
    $scores.GlobalAdmin = if ($globalAdmins.Count -le 5) { 2 } elseif ($globalAdmins.Count -le 10) { 1 } else { 0 }
} catch {
    Write-Host "  [SKIP] Global Admin count: $_" -ForegroundColor Gray
}

# Risky users
try {
    $riskyUsers = Get-MgRiskyUser -Filter "riskState eq 'atRisk'" -All
    Write-Host "  Risky users (atRisk): $($riskyUsers.Count)"
    $highRisk   = ($riskyUsers | Where-Object { $_.RiskLevel -eq 'high' }).Count
    Write-Host "  High-risk users: $highRisk"
    $metrics.RiskyUserCount     = $riskyUsers.Count
    $metrics.HighRiskUserCount  = $highRisk
    $scores.RiskyUsers = if ($highRisk -eq 0) { 2 } elseif ($highRisk -le 5) { 1 } else { 0 }
} catch {
    Write-Host "  [SKIP] Risky users: $_" -ForegroundColor Gray
}

# --- CA Policy Metrics ---
Write-Host "`n[2] CONDITIONAL ACCESS" -ForegroundColor Yellow
try {
    $policies       = Get-MgIdentityConditionalAccessPolicy -All
    $enforced       = ($policies | Where-Object { $_.State -eq 'enabled' }).Count
    $reportOnly     = ($policies | Where-Object { $_.State -eq 'enabledForReportingButNotEnforcing' }).Count
    $legacyBlock    = ($policies | Where-Object {
        $_.State -eq 'enabled' -and ($_.Conditions.ClientAppTypes -contains 'exchangeActiveSync' -or $_.Conditions.ClientAppTypes -contains 'other')
    }).Count
    Write-Host "  Total CA policies: $($policies.Count) ($enforced enforced, $reportOnly report-only)"
    Write-Host "  Legacy auth block policies: $legacyBlock"
    $metrics.CAPoliciesTotal    = $policies.Count
    $metrics.CAPoliciesEnforced = $enforced
    $metrics.LegacyAuthBlocked  = $legacyBlock -gt 0
    $scores.LegacyAuthBlock = if ($legacyBlock -gt 0) { 2 } else { 0 }
} catch {
    Write-Host "  [SKIP] CA policies: $_" -ForegroundColor Gray
}

# --- Sign-in Metrics ---
Write-Host "`n[3] SIGN-IN HEALTH" -ForegroundColor Yellow
try {
    $signins      = Get-MgAuditLogSignIn -Filter "createdDateTime ge $((Get-Date).AddDays(-7).ToString('yyyy-MM-dd'))" -Top 200
    $legacySignins = ($signins | Where-Object {
        $_.ClientAppUsed -in @('Exchange ActiveSync','IMAP4','MAPI','SMTP','POP3','Other clients')
    }).Count
    $legacyPct   = if ($signins.Count -gt 0) { [math]::Round(($legacySignins / $signins.Count) * 100, 1) } else { 0 }
    Write-Host "  Legacy auth sign-ins (7d sample, n=$($signins.Count)): $legacySignins ($legacyPct%)"
    $metrics.LegacyAuthSignInPct = $legacyPct
    $scores.LegacySignIns = if ($legacyPct -lt 1) { 2 } elseif ($legacyPct -lt 5) { 1 } else { 0 }
} catch {
    Write-Host "  [SKIP] Sign-in logs: $_" -ForegroundColor Gray
}

# --- Overall Score ---
$totalScore = ($scores.Values | Measure-Object -Sum).Sum
$maxScore   = $scores.Count * 2
$pct        = if ($maxScore -gt 0) { [math]::Round(($totalScore / $maxScore) * 100) } else { 0 }

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  ZT BASELINE SCORE: $pct% ($totalScore/$maxScore)" -ForegroundColor Cyan
$level = if ($pct -ge 80) { 'OPTIMAL' } elseif ($pct -ge 50) { 'ADVANCED' } else { 'TRADITIONAL' }
Write-Host "  Maturity Level: $level" -ForegroundColor $(if ($pct -ge 80) { 'Green' } elseif ($pct -ge 50) { 'Yellow' } else { 'Red' })
Write-Host "==========================================" -ForegroundColor Cyan

# Export JSON
$output = @{
    Timestamp      = $date.ToString('o')
    OverallScore   = $pct
    MaturityLevel  = $level
    ComponentScores = $scores
    Metrics        = $metrics
}
$output | ConvertTo-Json -Depth 4 | Out-File $outFile -Encoding UTF8
Write-Host "`nJSON exported: $outFile (compare monthly to show program progress)" -ForegroundColor Green
