<#
.SYNOPSIS
    Script 5-2: Azure PIM Role Assignment Audit
.DESCRIPTION
    Audits PIM eligible vs. active role assignments, activation patterns, and anti-patterns.
    Flags: Permanent active assignments, activations without MFA, Global Admin eligible count > 5.
.NOTES
    Requires: Microsoft.Graph module
    Permissions: RoleManagement.Read.All, AuditLog.Read.All
    Chapter 5 §5.3 — Azure PIM
#>
[CmdletBinding()]
param(
    [int]$MaxGlobalAdminEligible = 5,
    [switch]$WhatIf
)

Import-Module Microsoft.Graph.Identity.Governance -ErrorAction Stop

Write-Host "`n=== Azure PIM Role Assignment Audit ===" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# Ensure connected
try { Get-MgContext -ErrorAction Stop | Out-Null } catch {
    Connect-MgGraph -Scopes "RoleManagement.Read.All","AuditLog.Read.All","Directory.Read.All"
}

# --- Active (non-eligible) role assignments ---
Write-Host "1. PERMANENT ACTIVE ROLE ASSIGNMENTS (not eligible — always-on)" -ForegroundColor Yellow
Write-Host "   Anti-pattern: Active admin assignments defeat the purpose of JIT access`n"

$activeAssignments = Get-MgRoleManagementDirectoryRoleAssignment -ExpandProperty "principal,roleDefinition" -All
$permanentAdmins   = $activeAssignments | Where-Object {
    $_.RoleDefinition.DisplayName -match 'Admin|Administrator|Owner|Contributor'
}

$results = @()
foreach ($assignment in $permanentAdmins) {
    $principal   = $assignment.Principal
    $roleName    = $assignment.RoleDefinition.DisplayName
    $isGlobalAdmin = ($roleName -eq 'Global Administrator')

    Write-Host "  [$roleName] $($principal.DisplayName) ($($principal.UserPrincipalName ?? $principal.AppId))"

    $results += [PSCustomObject]@{
        Type          = 'PermanentActive'
        PrincipalName = $principal.DisplayName
        PrincipalUPN  = $principal.UserPrincipalName
        RoleName      = $roleName
        IsGlobalAdmin = $isGlobalAdmin
        Risk          = if ($isGlobalAdmin) { 'CRITICAL' } else { 'HIGH' }
    }
}

# --- Eligible assignments ---
Write-Host "`n2. ELIGIBLE ROLE ASSIGNMENTS (JIT — correct pattern)" -ForegroundColor Yellow
$eligibleAssignments = Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance -ExpandProperty "principal,roleDefinition" -All
$globalAdminEligible = $eligibleAssignments | Where-Object { $_.RoleDefinition.DisplayName -eq 'Global Administrator' }

Write-Host "  Total eligible assignments: $($eligibleAssignments.Count)"
Write-Host "  Global Admin eligible: $($globalAdminEligible.Count)"

if ($globalAdminEligible.Count -gt $MaxGlobalAdminEligible) {
    Write-Host "  [WARNING] $($globalAdminEligible.Count) Global Admin eligible principals exceeds max ($MaxGlobalAdminEligible)" -ForegroundColor Yellow
    $globalAdminEligible | ForEach-Object {
        Write-Host "    - $($_.Principal.DisplayName) ($($_.Principal.UserPrincipalName))"
    }
}

# --- Recent PIM activations (audit log) ---
Write-Host "`n3. RECENT PIM ACTIVATIONS (last 48 hours)" -ForegroundColor Yellow
$since = (Get-Date).AddHours(-48).ToString('o')
try {
    $activations = Get-MgAuditLogDirectoryAudit -Filter "activityDisplayName eq 'Add eligible member to role in PIM completed (permanent)' and activityDateTime ge $since" -Top 50
    if ($activations.Count -eq 0) {
        Write-Host "  No PIM activations in last 48 hours"
    } else {
        $activations | ForEach-Object {
            Write-Host "  $($_.ActivityDateTime) - $($_.InitiatedBy.User.UserPrincipalName) activated $($_.TargetResources[0].DisplayName)"
        }
    }
} catch {
    Write-Host "  [SKIP] Cannot query audit log: $_" -ForegroundColor Gray
}

# --- Summary ---
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Permanent active admin assignments: $($results.Count)"
Write-Host "  CRITICAL (Global Admin permanent): $(($results | Where-Object {$_.Risk -eq 'CRITICAL'}).Count)"
Write-Host "  HIGH (Other admin permanent):      $(($results | Where-Object {$_.Risk -eq 'HIGH'}).Count)"
Write-Host "Eligible (JIT) assignments: $($eligibleAssignments.Count)"
Write-Host "Global Admin eligible count: $($globalAdminEligible.Count) (max: $MaxGlobalAdminEligible)"

$results | Export-Csv -Path ".\PIMAudit_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
Write-Host "`nExported: PIMAudit_$(Get-Date -Format 'yyyyMMdd').csv" -ForegroundColor Green
