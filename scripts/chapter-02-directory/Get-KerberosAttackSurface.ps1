<#
.SYNOPSIS
    Script 2-3: Kerberos Attack Surface Audit
.DESCRIPTION
    Enumerates accounts vulnerable to Kerberoasting, AS-REP Roasting, and delegation abuse.
    - Kerberoastable: User accounts with ServicePrincipalName set
    - AS-REP Roastable: Accounts with pre-authentication disabled (DoesNotRequirePreAuth)
    - Unconstrained delegation: Computers and users trusted for delegation
    - krbtgt password age: Should be rotated every 180 days maximum
.NOTES
    Requires: ActiveDirectory module
    Chapter 2 §2.4 — Kerberos Attack Taxonomy
    Reference: https://attack.mitre.org/techniques/T1558/
#>
[CmdletBinding()]
param(
    [string]$Domain = (Get-ADDomain).DNSRoot,
    [int]$KrbtgtMaxAgeDays = 180
)

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "`n=== Kerberos Attack Surface Audit ===" -ForegroundColor Cyan
Write-Host "Domain: $Domain | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# -----------------------------------------------------------------------
# 1. KERBEROASTABLE ACCOUNTS (user accounts with SPNs)
# -----------------------------------------------------------------------
Write-Host "1. KERBEROASTABLE ACCOUNTS" -ForegroundColor Yellow
Write-Host "   (User accounts with ServicePrincipalName — TGS-REQ returns crackable ticket)"

$kerberoastable = Get-ADUser -Filter { ServicePrincipalName -ne "$null" } `
    -Properties ServicePrincipalName, PasswordLastSet, AdminCount, Enabled |
    Where-Object { $_.Enabled }

if ($kerberoastable.Count -eq 0) {
    Write-Host "   [OK] No kerberoastable user accounts found" -ForegroundColor Green
} else {
    Write-Host "   [RISK] $($kerberoastable.Count) kerberoastable user account(s):" -ForegroundColor Red
    $kerberoastable | ForEach-Object {
        $adminFlag = if ($_.AdminCount -eq 1) { " [ADMIN - CRITICAL]" } else { "" }
        Write-Host "   - $($_.SamAccountName)$adminFlag | SPNs: $($_.ServicePrincipalName -join ', ')"
        Write-Host "     Password last set: $($_.PasswordLastSet)"
    }
}

# -----------------------------------------------------------------------
# 2. AS-REP ROASTABLE ACCOUNTS (pre-auth disabled)
# -----------------------------------------------------------------------
Write-Host "`n2. AS-REP ROASTABLE ACCOUNTS" -ForegroundColor Yellow
Write-Host "   (DoesNotRequirePreAuth — KDC returns AS-REP without validating identity first)"

$asrepRoastable = Get-ADUser -Filter { DoesNotRequirePreAuth -eq $true } `
    -Properties DoesNotRequirePreAuth, PasswordLastSet, Enabled |
    Where-Object { $_.Enabled }

if ($asrepRoastable.Count -eq 0) {
    Write-Host "   [OK] No AS-REP roastable accounts found" -ForegroundColor Green
} else {
    Write-Host "   [RISK] $($asrepRoastable.Count) AS-REP roastable account(s):" -ForegroundColor Red
    $asrepRoastable | ForEach-Object {
        Write-Host "   - $($_.SamAccountName) | Password last set: $($_.PasswordLastSet)"
    }
    Write-Host "   Remediation: Set DoesNotRequirePreAuth = False unless explicitly required." -ForegroundColor Yellow
}

# -----------------------------------------------------------------------
# 3. UNCONSTRAINED DELEGATION
# -----------------------------------------------------------------------
Write-Host "`n3. UNCONSTRAINED DELEGATION" -ForegroundColor Yellow
Write-Host "   (TrustedForDelegation — receives user's TGT, can impersonate to ANY service)"

# Exclude Domain Controllers (they legitimately have unconstrained delegation)
$dcList = (Get-ADDomainController -Filter *).Name

$unconstrainedComputers = Get-ADComputer -Filter { TrustedForDelegation -eq $true } `
    -Properties TrustedForDelegation, OperatingSystem |
    Where-Object { $_.Name -notin $dcList }

$unconstrainedUsers = Get-ADUser -Filter { TrustedForDelegation -eq $true } `
    -Properties TrustedForDelegation, Enabled |
    Where-Object { $_.Enabled }

if ($unconstrainedComputers.Count -eq 0 -and $unconstrainedUsers.Count -eq 0) {
    Write-Host "   [OK] No non-DC systems with unconstrained delegation" -ForegroundColor Green
} else {
    if ($unconstrainedComputers.Count -gt 0) {
        Write-Host "   [CRITICAL] $($unconstrainedComputers.Count) non-DC computer(s) with unconstrained delegation:" -ForegroundColor Red
        $unconstrainedComputers | ForEach-Object {
            Write-Host "   - $($_.Name) ($($_.OperatingSystem))"
        }
    }
    if ($unconstrainedUsers.Count -gt 0) {
        Write-Host "   [CRITICAL] $($unconstrainedUsers.Count) user account(s) with unconstrained delegation:" -ForegroundColor Red
        $unconstrainedUsers | ForEach-Object { Write-Host "   - $($_.SamAccountName)" }
    }
    Write-Host "   Remediation: Convert to constrained or resource-based constrained delegation." -ForegroundColor Yellow
}

# -----------------------------------------------------------------------
# 4. KRBTGT PASSWORD AGE
# -----------------------------------------------------------------------
Write-Host "`n4. KRBTGT ACCOUNT PASSWORD AGE" -ForegroundColor Yellow
Write-Host "   (Golden Ticket attacks use compromised krbtgt hash — rotate every $KrbtgtMaxAgeDays days)"

$krbtgt = Get-ADUser krbtgt -Properties PasswordLastSet
$age = ((Get-Date) - $krbtgt.PasswordLastSet).Days

if ($age -gt $KrbtgtMaxAgeDays) {
    Write-Host "   [WARNING] krbtgt password is $age days old (threshold: $KrbtgtMaxAgeDays days)" -ForegroundColor Red
    Write-Host "   Last set: $($krbtgt.PasswordLastSet)" -ForegroundColor Gray
    Write-Host "   Remediation: Rotate krbtgt TWICE (24h apart) to invalidate existing tickets." -ForegroundColor Yellow
} else {
    Write-Host "   [OK] krbtgt password age: $age days (last set: $($krbtgt.PasswordLastSet))" -ForegroundColor Green
}

# -----------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------
Write-Host "`n=== ATTACK SURFACE SUMMARY ===" -ForegroundColor Cyan
Write-Host "Kerberoastable accounts:      $($kerberoastable.Count)"
Write-Host "AS-REP Roastable accounts:    $($asrepRoastable.Count)"
Write-Host "Unconstrained delegation:     $($unconstrainedComputers.Count + $unconstrainedUsers.Count) (non-DC)"
Write-Host "krbtgt age (days):            $age / $KrbtgtMaxAgeDays max"

$totalRisk = $kerberoastable.Count + $asrepRoastable.Count + $unconstrainedComputers.Count + $unconstrainedUsers.Count
if ($totalRisk -eq 0 -and $age -le $KrbtgtMaxAgeDays) {
    Write-Host "`n[CLEAN] No Kerberos attack surface findings." -ForegroundColor Green
} else {
    Write-Host "`n[ACTION REQUIRED] Address findings above before next penetration test." -ForegroundColor Red
}
