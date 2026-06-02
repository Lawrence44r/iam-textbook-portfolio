<#
.SYNOPSIS
    Script 2-6: GPO Coverage and Inheritance Audit
.DESCRIPTION
    Finds orphaned/unlinked GPOs, OUs with Block Inheritance, and GPO coverage gaps.
    Unlinked GPOs are a maintenance overhead and potential confusion source.
    OUs with Block Inheritance may be missing critical security policies.
.NOTES
    Requires: GroupPolicy module (RSAT), ActiveDirectory module
    Chapter 2 §2.3 — GPO Processing Order (LSDOU)
#>
[CmdletBinding()]
param(
    [string]$Domain = (Get-ADDomain).DNSRoot
)

Import-Module GroupPolicy  -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "`n=== GPO Coverage and Inheritance Audit ===" -ForegroundColor Cyan
Write-Host "Domain: $Domain | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# --- Unlinked GPOs ---
Write-Host "1. UNLINKED GPOs (exist in SYSVOL but linked to no OU)" -ForegroundColor Yellow
$allGPOs    = Get-GPO -All -Domain $Domain
$linkedGPOs = @{}

$ous = Get-ADOrganizationalUnit -Filter * -Properties gpLink
foreach ($ou in $ous) {
    if ($ou.gpLink) {
        $ou.gpLink -split '\]\[' | ForEach-Object {
            if ($_ -match 'LDAP://(.+?);') {
                $linkedGPOs[$Matches[1].ToLower()] = $true
            }
        }
    }
}

$unlinked = $allGPOs | Where-Object {
    $gpoPath = "cn={$($_.Id)},cn=policies,cn=system,$(Get-ADDomain -Identity $Domain | Select-Object -ExpandProperty DistinguishedName)"
    -not $linkedGPOs.ContainsKey($gpoPath.ToLower())
}

if ($unlinked.Count -eq 0) {
    Write-Host "   [OK] All GPOs are linked" -ForegroundColor Green
} else {
    Write-Host "   [INFO] $($unlinked.Count) unlinked GPO(s):" -ForegroundColor Yellow
    $unlinked | ForEach-Object {
        Write-Host "   - $($_.DisplayName) [ID: $($_.Id)] [Modified: $($_.ModificationTime.ToString('yyyy-MM-dd'))]"
    }
}

# --- OUs with Block Inheritance ---
Write-Host "`n2. OUs WITH BLOCK INHERITANCE" -ForegroundColor Yellow
Write-Host "   (Policies from parent OUs — including domain-level security baselines — do not apply)"

$blockingOUs = @()
$allOUs = Get-ADOrganizationalUnit -Filter * -Properties gPOptions, DistinguishedName
foreach ($ou in $allOUs) {
    # gPOptions = 1 means Block Inheritance is set
    if ($ou.gPOptions -band 1) {
        $blockingOUs += $ou
        Write-Host "   [BLOCK INHERITANCE] $($ou.DistinguishedName)" -ForegroundColor Yellow
    }
}

if ($blockingOUs.Count -eq 0) {
    Write-Host "   [OK] No OUs with Block Inheritance" -ForegroundColor Green
}

# --- Summary ---
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total GPOs:               $($allGPOs.Count)"
Write-Host "Unlinked GPOs:            $($unlinked.Count)"
Write-Host "OUs blocking inheritance: $($blockingOUs.Count)"
Write-Host "`nLSDOU Processing Order (reminder):"
Write-Host "  Local → Site → Domain → OU (child OUs last, lowest OU wins on conflict)"

$unlinked | Select-Object DisplayName, Id, ModificationTime |
    Export-Csv -Path ".\UnlinkedGPOs_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
Write-Host "`nExported: UnlinkedGPOs_$(Get-Date -Format 'yyyyMMdd').csv" -ForegroundColor Green
