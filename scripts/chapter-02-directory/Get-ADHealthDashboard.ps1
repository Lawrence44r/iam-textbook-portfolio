<#
.SYNOPSIS
    Script 2-9: AD Health Dashboard
.DESCRIPTION
    Complete AD operational health check: replication status, account statistics,
    privileged group membership, FSMO confirmation, krbtgt age, and DC OS versions.
    Exports JSON for trend tracking.
.NOTES
    Requires: ActiveDirectory module; Domain Admin for replication queries
    Chapter 2 — AD Health
#>
[CmdletBinding()]
param(
    [string]$OutputJson = ".\ADHealth_$(Get-Date -Format 'yyyyMMdd').json"
)

Import-Module ActiveDirectory -ErrorAction Stop

$report = @{}
$warnings = @()

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  Active Directory Health Dashboard" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "==========================================" -ForegroundColor Cyan

# --- Replication Status ---
Write-Host "`n[1] Replication Status" -ForegroundColor Yellow
try {
    $replSummary = repadmin /replsummary 2>&1
    $failLines = $replSummary | Where-Object { $_ -match 'FAIL|Error' }
    if ($failLines) {
        Write-Host "  [WARNING] Replication failures detected:" -ForegroundColor Red
        $failLines | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        $warnings += "Replication failures detected"
    } else {
        Write-Host "  [OK] No replication failures" -ForegroundColor Green
    }
    $report.ReplicationStatus = if ($failLines) { 'DEGRADED' } else { 'HEALTHY' }
} catch {
    Write-Host "  [SKIP] repadmin not available or insufficient permissions" -ForegroundColor Gray
    $report.ReplicationStatus = 'UNKNOWN'
}

# --- Account Statistics ---
Write-Host "`n[2] Account Statistics" -ForegroundColor Yellow
$allUsers  = Get-ADUser -Filter * -Properties Enabled, LastLogonDate, PasswordLastSet
$enabled   = ($allUsers | Where-Object { $_.Enabled }).Count
$disabled  = ($allUsers | Where-Object { -not $_.Enabled }).Count
$stale90   = ($allUsers | Where-Object {
    $_.Enabled -and ($_.LastLogonDate -lt (Get-Date).AddDays(-90) -or $_.LastLogonDate -eq $null)
}).Count

Write-Host "  Total user accounts: $($allUsers.Count)"
Write-Host "  Enabled:  $enabled"
Write-Host "  Disabled: $disabled"
Write-Host "  Stale (enabled, no logon >90 days): $stale90"

if ($stale90 -gt 50) { $warnings += "High stale account count: $stale90" }

$report.AccountStats = @{
    Total    = $allUsers.Count
    Enabled  = $enabled
    Disabled = $disabled
    Stale90  = $stale90
}

# --- Privileged Group Membership ---
Write-Host "`n[3] Privileged Group Membership" -ForegroundColor Yellow
$privGroups = @('Domain Admins', 'Enterprise Admins', 'Schema Admins', 'Administrators')
$privReport = @{}

foreach ($group in $privGroups) {
    try {
        $members = Get-ADGroupMember -Identity $group -Recursive -ErrorAction Stop
        $enabledCount = ($members | ForEach-Object {
            Get-ADUser $_.SamAccountName -Properties Enabled -ErrorAction SilentlyContinue
        } | Where-Object { $_.Enabled }).Count
        Write-Host "  $group`: $($members.Count) members ($enabledCount enabled)"
        if ($members.Count -gt 10) {
            Write-Host "  [WARNING] $group has more than 10 members" -ForegroundColor Yellow
            $warnings += "$group has $($members.Count) members"
        }
        $privReport[$group] = $members.Count
    } catch {
        Write-Host "  $group`: [ERROR reading group]" -ForegroundColor Red
    }
}
$report.PrivilegedGroups = $privReport

# --- FSMO Roles ---
Write-Host "`n[4] FSMO Role Confirmation" -ForegroundColor Yellow
$forest = Get-ADForest
$domain = Get-ADDomain
Write-Host "  Schema Master:          $($forest.SchemaMaster)"
Write-Host "  Domain Naming Master:   $($forest.DomainNamingMaster)"
Write-Host "  PDC Emulator:           $($domain.PDCEmulator)"
Write-Host "  RID Master:             $($domain.RIDMaster)"
Write-Host "  Infrastructure Master:  $($domain.InfrastructureMaster)"
$report.FSMORoles = @{
    SchemaMaster        = $forest.SchemaMaster
    DomainNamingMaster  = $forest.DomainNamingMaster
    PDCEmulator         = $domain.PDCEmulator
    RIDMaster           = $domain.RIDMaster
    InfrastructureMaster = $domain.InfrastructureMaster
}

# --- krbtgt Password Age ---
Write-Host "`n[5] krbtgt Password Age" -ForegroundColor Yellow
$krbtgt = Get-ADUser krbtgt -Properties PasswordLastSet
$krbtgtAge = ((Get-Date) - $krbtgt.PasswordLastSet).Days
if ($krbtgtAge -gt 180) {
    Write-Host "  [WARNING] krbtgt is $krbtgtAge days old (max recommended: 180)" -ForegroundColor Red
    $warnings += "krbtgt password age: $krbtgtAge days"
} else {
    Write-Host "  [OK] krbtgt age: $krbtgtAge days" -ForegroundColor Green
}
$report.KrbtgtAgeDays = $krbtgtAge

# --- DC Operating System Versions ---
Write-Host "`n[6] Domain Controller OS Versions" -ForegroundColor Yellow
$dcs = Get-ADDomainController -Filter * | Select-Object Name, OperatingSystem, IPv4Address, IsGlobalCatalog
$dcs | ForEach-Object {
    $gcTag = if ($_.IsGlobalCatalog) { " [GC]" } else { "" }
    Write-Host "  $($_.Name)$gcTag - $($_.OperatingSystem) ($($_.IPv4Address))"
    if ($_.OperatingSystem -match '2008|2012') {
        Write-Host "    [WARNING] End-of-support OS detected" -ForegroundColor Yellow
        $warnings += "End-of-support DC OS: $($_.Name) running $($_.OperatingSystem)"
    }
}
$report.DomainControllers = $dcs | ForEach-Object { @{
    Name = $_.Name; OS = $_.OperatingSystem; GC = $_.IsGlobalCatalog
}}

# --- Final Summary ---
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  HEALTH SUMMARY" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
if ($warnings.Count -eq 0) {
    Write-Host "  [HEALTHY] No warnings detected" -ForegroundColor Green
} else {
    Write-Host "  [$($warnings.Count) WARNING(S)]:" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

$report.Warnings      = $warnings
$report.OverallStatus = if ($warnings.Count -eq 0) { 'HEALTHY' } else { 'WARNING' }
$report.Timestamp     = (Get-Date -Format 'o')

$report | ConvertTo-Json -Depth 5 | Out-File $OutputJson -Encoding UTF8
Write-Host "`nJSON exported: $OutputJson" -ForegroundColor Green
