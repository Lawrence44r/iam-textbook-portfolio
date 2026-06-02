<#
.SYNOPSIS
    Script 7-5: SoD Violation Detection
.DESCRIPTION
    Detects Segregation of Duties conflicts across AD group memberships.
    Reads SoD matrix from CSV (Role1, Role2, Severity, Description, CompensatingControl).
    Reports per-user violations with conflicting groups, severity, and days violation existed.
.PARAMETER SoDMatrixPath  Path to SoD matrix CSV file
.PARAMETER SearchBase     AD OU to search (default: entire domain)
.NOTES
    Chapter 7 §7.6 — SoD Matrix Design
.EXAMPLE
    .\Find-SoDViolations.ps1 -SoDMatrixPath ".\sod-matrix.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SoDMatrixPath,
    [string]$SearchBase = (Get-ADDomain).DistinguishedName,
    [string]$OutputPath = ".\SoDViolations_$(Get-Date -Format 'yyyyMMdd').csv"
)

Import-Module ActiveDirectory -ErrorAction Stop

if (-not (Test-Path $SoDMatrixPath)) {
    Write-Host "[ERROR] SoD matrix not found: $SoDMatrixPath" -ForegroundColor Red
    Write-Host "Expected format: Role1,Role2,Severity,Description,CompensatingControl"
    exit 1
}

$sodMatrix = Import-Csv -Path $SoDMatrixPath
Write-Host "`n=== SoD Violation Detection ===" -ForegroundColor Cyan
Write-Host "SoD matrix: $($sodMatrix.Count) rules | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# Build user → groups map (flatten nested groups)
Write-Host "Building user-to-group membership index..." -ForegroundColor Gray
$userGroups = @{}
$allUsers   = Get-ADUser -Filter { Enabled -eq $true } -SearchBase $SearchBase -Properties MemberOf

foreach ($user in $allUsers) {
    $flatGroups = @()
    foreach ($groupDN in $user.MemberOf) {
        try {
            $grp = Get-ADGroup $groupDN -Properties whenCreated
            $flatGroups += @{ Name = $grp.Name; WhenCreated = $grp.whenCreated; DN = $groupDN }
        } catch {}
    }
    $userGroups[$user.SamAccountName] = $flatGroups
}

Write-Host "Users indexed: $($userGroups.Count)"
Write-Host "Checking $($sodMatrix.Count) SoD rules...`n"

$violations = @()

foreach ($user in $userGroups.Keys) {
    $memberGroups = $userGroups[$user]
    $memberNames  = $memberGroups | ForEach-Object { $_.Name }

    foreach ($rule in $sodMatrix) {
        $hasRole1 = $memberNames -contains $rule.Role1
        $hasRole2 = $memberNames -contains $rule.Role2

        if ($hasRole1 -and $hasRole2) {
            # Find how long the conflict has existed (use the later group's creation date)
            $g1 = $memberGroups | Where-Object { $_.Name -eq $rule.Role1 } | Select-Object -First 1
            $g2 = $memberGroups | Where-Object { $_.Name -eq $rule.Role2 } | Select-Object -First 1
            $conflictStart = if ($g1.WhenCreated -gt $g2.WhenCreated) { $g1.WhenCreated } else { $g2.WhenCreated }
            $daysSinceConflict = ((Get-Date) - $conflictStart).Days

            $violation = [PSCustomObject]@{
                User                 = $user
                ConflictingRole1     = $rule.Role1
                ConflictingRole2     = $rule.Role2
                Severity             = $rule.Severity
                Description          = $rule.Description
                CompensatingControl  = $rule.CompensatingControl
                DaysInViolation      = $daysSinceConflict
                ConflictStartApprox  = $conflictStart.ToString('yyyy-MM-dd')
            }
            $violations += $violation

            $color = switch ($rule.Severity.ToUpper()) { 'CRITICAL' { 'Red' } 'HIGH' { 'Yellow' } default { 'White' } }
            Write-Host "[$($rule.Severity)] $user`: $($rule.Role1) + $($rule.Role2)" -ForegroundColor $color
            Write-Host "  Risk: $($rule.Description)"
            Write-Host "  Conflict duration: $daysSinceConflict days (since ~$($conflictStart.ToString('yyyy-MM-dd')))"
            if ($rule.CompensatingControl -ne 'None - hard block') {
                Write-Host "  Compensating control: $($rule.CompensatingControl)" -ForegroundColor Gray
            }
        }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "SoD rules evaluated: $($sodMatrix.Count)"
Write-Host "Users checked:       $($userGroups.Count)"
Write-Host "Violations found:    $($violations.Count)"
$violations | Group-Object Severity | ForEach-Object {
    $color = switch ($_.Name.ToUpper()) { 'CRITICAL' { 'Red' } 'HIGH' { 'Yellow' } default { 'White' } }
    Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor $color
}

if ($violations.Count -gt 0) {
    $violations | Sort-Object Severity, DaysInViolation -Descending | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-Host "`nExported: $OutputPath" -ForegroundColor Green
    Write-Host "CRITICAL violations require immediate remediation — no compensating control is acceptable." -ForegroundColor Red
} else {
    Write-Host "[CLEAN] No SoD violations detected." -ForegroundColor Green
}
