<#
.SYNOPSIS
    Script 6-1: Conditional Access Policy Gap Analysis
.DESCRIPTION
    Evaluates CA policy set against the tiered model and flags gaps.
    Tiers: B (Baseline), I (Identity Protection), D (Device), P (Privileged), A (Application)
.NOTES
    Requires: Microsoft.Graph module
    Permissions: Policy.Read.All, Directory.Read.All
    Chapter 6 §6.4 — CA Tiered Model
#>
[CmdletBinding()]
param()

Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop
try { Get-MgContext -ErrorAction Stop | Out-Null } catch {
    Connect-MgGraph -Scopes "Policy.Read.All","Directory.Read.All"
}

Write-Host "`n=== Conditional Access Policy Gap Analysis ===" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$policies = Get-MgIdentityConditionalAccessPolicy -All

Write-Host "Total CA policies: $($policies.Count)"
Write-Host "  Enabled (enforced):  $(($policies | Where-Object {$_.State -eq 'enabled'}).Count)"
Write-Host "  Report-only:         $(($policies | Where-Object {$_.State -eq 'enabledForReportingButNotEnforcing'}).Count)"
Write-Host "  Disabled:            $(($policies | Where-Object {$_.State -eq 'disabled'}).Count)`n"

# Helper: check if any enabled policy covers a condition
function Find-PolicyCoverage {
    param([string]$Description, [scriptblock]$Condition)
    $matching = $policies | Where-Object { $_.State -eq 'enabled' -and (& $Condition $_) }
    $reportOnly = $policies | Where-Object { $_.State -eq 'enabledForReportingButNotEnforcing' -and (& $Condition $_) }
    return @{ Matching = $matching; ReportOnly = $reportOnly }
}

$gaps  = @()
$passes = @()

# -----------------------------------------------------------------------
# TIER B — BASELINE
# -----------------------------------------------------------------------
Write-Host "TIER B — BASELINE" -ForegroundColor Yellow

# B-01: Block legacy authentication
$legacyBlock = Find-PolicyCoverage "Block legacy auth" {
    param($p)
    $p.Conditions.ClientAppTypes -contains 'exchangeActiveSync' -or
    $p.Conditions.ClientAppTypes -contains 'other'
}
if ($legacyBlock.Matching.Count -gt 0) {
    Write-Host "  [PASS] B-01: Legacy auth block policy found: '$($legacyBlock.Matching[0].DisplayName)'" -ForegroundColor Green
    $passes += "B-01"
} elseif ($legacyBlock.ReportOnly.Count -gt 0) {
    Write-Host "  [WARN] B-01: Legacy auth block is report-only — not enforced" -ForegroundColor Yellow
    $gaps += @{ Tier = 'B-01'; Gap = 'Legacy auth block in report-only; not enforced' }
} else {
    Write-Host "  [FAIL] B-01: No legacy authentication block policy found!" -ForegroundColor Red
    $gaps += @{ Tier = 'B-01'; Gap = 'No legacy authentication block policy exists' }
}

# B-02: MFA for all users
$mfaAll = Find-PolicyCoverage "MFA all users" {
    param($p)
    ($p.Conditions.Users.IncludeUsers -contains 'All' -or $p.Conditions.Users.IncludeUsers.Count -gt 100) -and
    $p.GrantControls.BuiltInControls -contains 'mfa'
}
if ($mfaAll.Matching.Count -gt 0) {
    Write-Host "  [PASS] B-02: MFA for all users policy found" -ForegroundColor Green
    $passes += "B-02"
} else {
    Write-Host "  [FAIL] B-02: No MFA-for-all-users policy detected!" -ForegroundColor Red
    $gaps += @{ Tier = 'B-02'; Gap = 'No MFA policy covering all users' }
}

# -----------------------------------------------------------------------
# TIER I — IDENTITY PROTECTION
# -----------------------------------------------------------------------
Write-Host "`nTIER I — IDENTITY PROTECTION" -ForegroundColor Yellow

# I-01: Sign-in risk → MFA
$signinRiskMFA = Find-PolicyCoverage "Sign-in risk MFA" {
    param($p)
    $p.Conditions.SignInRiskLevels.Count -gt 0 -and $p.GrantControls.BuiltInControls -contains 'mfa'
}
if ($signinRiskMFA.Matching.Count -gt 0) {
    Write-Host "  [PASS] I-01: Sign-in risk → MFA policy found" -ForegroundColor Green
    $passes += "I-01"
} else {
    Write-Host "  [FAIL] I-01: No sign-in risk → MFA policy (requires Entra ID P2)" -ForegroundColor Red
    $gaps += @{ Tier = 'I-01'; Gap = 'No sign-in risk → MFA policy' }
}

# I-02: User risk → password change
$userRiskPwChange = Find-PolicyCoverage "User risk password change" {
    param($p)
    $p.Conditions.UserRiskLevels.Count -gt 0 -and $p.GrantControls.BuiltInControls -contains 'passwordChange'
}
if ($userRiskPwChange.Matching.Count -gt 0) {
    Write-Host "  [PASS] I-02: User risk → password change policy found" -ForegroundColor Green
    $passes += "I-02"
} else {
    Write-Host "  [FAIL] I-02: No user risk → password change policy" -ForegroundColor Red
    $gaps += @{ Tier = 'I-02'; Gap = 'No user risk → password change policy' }
}

# -----------------------------------------------------------------------
# TIER P — PRIVILEGED
# -----------------------------------------------------------------------
Write-Host "`nTIER P — PRIVILEGED" -ForegroundColor Yellow

$adminRoles = @('62e90394-69f5-4237-9190-012177145e10',   # Global Administrator
                 '194ae4cb-b126-40b2-bd5b-6091b380977d',   # Security Administrator
                 'f28a1f50-f6e7-4571-818b-6a12f2af6b6c')   # SharePoint Administrator

$adminMFA = Find-PolicyCoverage "Admin MFA" {
    param($p)
    $p.Conditions.Users.IncludeRoles.Count -gt 0 -and
    ($p.GrantControls.BuiltInControls -contains 'mfa' -or
     $p.GrantControls.AuthenticationStrength.Id -ne $null)
}
if ($adminMFA.Matching.Count -gt 0) {
    Write-Host "  [PASS] P-01: Admin role MFA policy found" -ForegroundColor Green
    $passes += "P-01"
} else {
    Write-Host "  [FAIL] P-01: No MFA policy for admin roles!" -ForegroundColor Red
    $gaps += @{ Tier = 'P-01'; Gap = 'No MFA policy targeting admin roles' }
}

# -----------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Checks passed: $($passes.Count)"
Write-Host "Gaps found:    $($gaps.Count)"

if ($gaps.Count -gt 0) {
    Write-Host "`nPRIORITY GAPS (remediate in order):" -ForegroundColor Red
    $gaps | ForEach-Object { Write-Host "  [$($_.Tier)] $($_.Gap)" }
}

# Export all policies
$policies | Select-Object DisplayName, State, @{N='Users';E={$_.Conditions.Users.IncludeUsers -join ','}},
    @{N='ClientApps';E={$_.Conditions.ClientAppTypes -join ','}},
    @{N='Grant';E={$_.GrantControls.BuiltInControls -join ','}} |
    Export-Csv -Path ".\CAPolicies_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
Write-Host "`nAll policies exported: CAPolicies_$(Get-Date -Format 'yyyyMMdd').csv" -ForegroundColor Green
