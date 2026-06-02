<#
.SYNOPSIS
    Script 2-5: Stale Group Detection
.DESCRIPTION
    Finds empty groups and groups with no recent membership changes (stale cleanup candidates).
    Empty groups still appear in user token PAC and consume token space.
.NOTES
    Requires: ActiveDirectory module
    Chapter 2 — IGA hygiene
#>
[CmdletBinding()]
param(
    [int]$StaleGroupDays = 365,
    [string]$SearchBase = (Get-ADDomain).DistinguishedName
)

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "`n=== Empty and Stale Group Detection ===" -ForegroundColor Cyan
Write-Host "Stale threshold: $StaleGroupDays days | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$cutoff = (Get-Date).AddDays(-$StaleGroupDays)
$allGroups = Get-ADGroup -Filter * -SearchBase $SearchBase -Properties Members, whenChanged, Description, ManagedBy

$emptyGroups = @()
$staleGroups = @()

foreach ($group in $allGroups) {
    $memberCount = ($group.Members | Measure-Object).Count

    if ($memberCount -eq 0) {
        $emptyGroups += [PSCustomObject]@{
            Name        = $group.Name
            Scope       = $group.GroupScope
            WhenChanged = $group.whenChanged
            Description = $group.Description
            ManagedBy   = $group.ManagedBy
            DN          = $group.DistinguishedName
        }
    } elseif ($group.whenChanged -lt $cutoff) {
        $staleGroups += [PSCustomObject]@{
            Name        = $group.Name
            Scope       = $group.GroupScope
            MemberCount = $memberCount
            WhenChanged = $group.whenChanged
            DaysSinceChange = ((Get-Date) - $group.whenChanged).Days
            Description = $group.Description
            ManagedBy   = $group.ManagedBy
            DN          = $group.DistinguishedName
        }
    }
}

Write-Host "EMPTY GROUPS ($($emptyGroups.Count)):" -ForegroundColor Yellow
$emptyGroups | Select-Object -First 20 | ForEach-Object {
    Write-Host "  $($_.Name) [last changed: $($_.WhenChanged.ToString('yyyy-MM-dd'))]"
}
if ($emptyGroups.Count -gt 20) { Write-Host "  ... and $($emptyGroups.Count - 20) more. See CSV export." }

Write-Host "`nSTALE GROUPS — no changes in $StaleGroupDays+ days ($($staleGroups.Count)):" -ForegroundColor Yellow
$staleGroups | Sort-Object DaysSinceChange -Descending | Select-Object -First 20 | ForEach-Object {
    Write-Host "  $($_.DaysSinceChange)d unchanged: $($_.Name) ($($_.MemberCount) members)"
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total groups:   $($allGroups.Count)"
Write-Host "Empty:          $($emptyGroups.Count)"
Write-Host "Stale (>$StaleGroupDays days): $($staleGroups.Count)"
Write-Host "Cleanup candidates: $($emptyGroups.Count + $staleGroups.Count)"

$emptyGroups | Export-Csv -Path ".\EmptyGroups_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
$staleGroups | Export-Csv -Path ".\StaleGroups_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
Write-Host "`nExported: EmptyGroups_*.csv and StaleGroups_*.csv" -ForegroundColor Green
