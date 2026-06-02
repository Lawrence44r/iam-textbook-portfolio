<#
.SYNOPSIS
    Script 2-8: Trust and SID Filtering Audit
.DESCRIPTION
    Enumerates all AD trusts and verifies SID filtering (quarantine) is enabled.
    Trusts without SID filtering allow sIDHistory-based privilege escalation attacks.
.NOTES
    Requires: ActiveDirectory module
    Chapter 2 §2.6 — Trust Architecture
#>
[CmdletBinding()]
param(
    [string]$ForestName = (Get-ADForest).Name
)

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "`n=== Trust and SID Filtering Audit ===" -ForegroundColor Cyan
Write-Host "Forest: $ForestName | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$allTrusts = @()
$forest    = Get-ADForest -Identity $ForestName

foreach ($domainName in $forest.Domains) {
    $trusts = Get-ADTrust -Filter * -Server $domainName -Properties * -ErrorAction SilentlyContinue
    foreach ($trust in $trusts) {
        $sidFiltering = $trust.SIDFilteringQuarantined
        $risk = if (-not $sidFiltering) { 'HIGH' } else { 'OK' }

        $trustObj = [PSCustomObject]@{
            SourceDomain     = $domainName
            TargetDomain     = $trust.Target
            TrustType        = $trust.TrustType
            Direction        = $trust.Direction
            Transitive       = $trust.IsTransitive
            SIDFiltering     = $sidFiltering
            ForestTransitive = $trust.ForestTransitive
            SelectiveAuth    = $trust.SelectiveAuthentication
            Risk             = $risk
        }
        $allTrusts += $trustObj

        $color = if ($risk -eq 'HIGH') { 'Red' } else { 'Green' }
        Write-Host "Trust: $domainName -> $($trust.Target)" -ForegroundColor $color
        Write-Host "  Type:          $($trust.TrustType)"
        Write-Host "  Direction:     $($trust.Direction)"
        Write-Host "  Transitive:    $($trust.IsTransitive)"
        Write-Host "  SID Filtering: $(if ($sidFiltering) { '[ENABLED - OK]' } else { '[DISABLED - RISK: sIDHistory escalation possible]' })"
        Write-Host "  Selective Auth:$(if ($trust.SelectiveAuthentication) { '[ENABLED - Restricts auth to specific resources]' } else { '[DISABLED - All resources accessible]' })"
        Write-Host ""
    }
}

$riskyTrusts = $allTrusts | Where-Object { $_.Risk -eq 'HIGH' }
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Total trusts: $($allTrusts.Count)"
Write-Host "Without SID filtering (HIGH RISK): $($riskyTrusts.Count)"

if ($riskyTrusts.Count -gt 0) {
    Write-Host "`n[ACTION REQUIRED] Enable SID filtering on the following trusts:" -ForegroundColor Red
    $riskyTrusts | ForEach-Object {
        Write-Host "  $($_.SourceDomain) -> $($_.TargetDomain)"
        Write-Host "  Command: netdom trust $($_.SourceDomain) /domain:$($_.TargetDomain) /quarantine:yes" -ForegroundColor Yellow
    }
    Write-Host "`nNote: Enabling SID filtering breaks sIDHistory migration scenarios." -ForegroundColor Gray
    Write-Host "Verify no ongoing migrations rely on sIDHistory before enabling." -ForegroundColor Gray
}

$allTrusts | Export-Csv -Path ".\TrustAudit_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
Write-Host "`nExported: TrustAudit_$(Get-Date -Format 'yyyyMMdd').csv" -ForegroundColor Green
