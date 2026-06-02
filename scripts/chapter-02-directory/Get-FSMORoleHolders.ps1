<#
.SYNOPSIS
    Script 2-1: FSMO Role Holder Audit
.DESCRIPTION
    Identifies all FSMO role holders across the forest and all domains.
    Flags Infrastructure Master co-location with Global Catalog server in multi-domain forests.
.NOTES
    Requires: ActiveDirectory module (RSAT)
    Permissions: Domain Users (read-only)
    Chapter 2 §2.2 — FSMO Roles and Traps
#>
[CmdletBinding()]
param(
    [string]$ForestName = (Get-ADForest).Name
)

Import-Module ActiveDirectory -ErrorAction Stop

function Test-GlobalCatalogCoLocation {
    param($DCName, $DomainDN)
    $dc = Get-ADDomainController -Filter { Name -eq $DCName } -ErrorAction SilentlyContinue
    if ($dc -and $dc.IsGlobalCatalog) { return $true }
    return $false
}

Write-Host "`n=== FSMO Role Holder Audit ===" -ForegroundColor Cyan
Write-Host "Forest: $ForestName" -ForegroundColor Gray
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# --- Forest-level roles ---
$forest = Get-ADForest -Identity $ForestName
Write-Host "FOREST-LEVEL ROLES" -ForegroundColor Yellow
Write-Host "-" * 40
Write-Host "Schema Master:          $($forest.SchemaMaster)"
Write-Host "Domain Naming Master:   $($forest.DomainNamingMaster)"

# --- Per-domain roles ---
Write-Host "`nDOMAIN-LEVEL ROLES" -ForegroundColor Yellow
Write-Host "-" * 40

$results = @()
foreach ($domainName in $forest.Domains) {
    $domain = Get-ADDomain -Identity $domainName
    Write-Host "`nDomain: $domainName"
    Write-Host "  PDC Emulator:          $($domain.PDCEmulator)"
    Write-Host "  RID Master:            $($domain.RIDMaster)"
    Write-Host "  Infrastructure Master: $($domain.InfrastructureMaster)"

    # Check: Infrastructure Master co-located with GC in a multi-domain forest?
    $isMultiDomain = ($forest.Domains.Count -gt 1)
    $infraMasterHostname = $domain.InfrastructureMaster.Split('.')[0]
    $coLocated = Test-GlobalCatalogCoLocation -DCName $infraMasterHostname -DomainDN $domain.DistinguishedName

    if ($isMultiDomain -and $coLocated) {
        Write-Host "  [WARNING] Infrastructure Master is co-located with a Global Catalog server!" -ForegroundColor Red
        Write-Host "  This causes phantom object resolution failures in multi-domain forests." -ForegroundColor Red
    } elseif ($isMultiDomain) {
        Write-Host "  [OK] Infrastructure Master is NOT co-located with GC" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Single-domain forest — GC co-location is acceptable" -ForegroundColor Gray
    }

    $results += [PSCustomObject]@{
        Domain               = $domainName
        PDCEmulator          = $domain.PDCEmulator
        RIDMaster            = $domain.RIDMaster
        InfrastructureMaster = $domain.InfrastructureMaster
        InfraGCCoLocated     = $coLocated
        MultiDomainForest    = $isMultiDomain
        RiskFlag             = ($isMultiDomain -and $coLocated)
    }
}

Write-Host "`nFOREST SUMMARY" -ForegroundColor Yellow
Write-Host "-" * 40
Write-Host "Schema Master:        $($forest.SchemaMaster)"
Write-Host "Domain Naming Master: $($forest.DomainNamingMaster)"
Write-Host "Total domains:        $($forest.Domains.Count)"

$riskyDomains = $results | Where-Object { $_.RiskFlag }
if ($riskyDomains) {
    Write-Host "`n[ACTION REQUIRED] $($riskyDomains.Count) domain(s) have Infrastructure Master co-located with GC" -ForegroundColor Red
    Write-Host "Remediation: Move Infrastructure Master role to a DC that is NOT a Global Catalog server." -ForegroundColor Yellow
}

$results | Export-Csv -Path ".\FSMORoleAudit_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
Write-Host "`nExported: FSMORoleAudit_$(Get-Date -Format 'yyyyMMdd').csv" -ForegroundColor Green
