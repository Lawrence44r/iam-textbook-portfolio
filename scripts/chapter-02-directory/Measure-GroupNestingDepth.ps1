<#
.SYNOPSIS
    Script 2-4: Group Nesting and Universal Group Audit
.DESCRIPTION
    Finds deeply nested groups contributing to Kerberos PAC token bloat.
    Kerberos tickets grow with each nested group SID; deeply nested groups
    cause "HTTP 400 Bad Request" and authentication failures.
.NOTES
    Requires: ActiveDirectory module
    Chapter 2 §2.3 — Group Scope and Token Bloat
#>
[CmdletBinding()]
param(
    [int]$MaxNestingThreshold = 3,
    [string]$SearchBase = (Get-ADDomain).DistinguishedName
)

Import-Module ActiveDirectory -ErrorAction Stop

function Get-GroupNestingDepth {
    param([string]$GroupDN, [int]$CurrentDepth = 0, [System.Collections.Generic.HashSet[string]]$Visited = $null)

    if ($null -eq $Visited) { $Visited = [System.Collections.Generic.HashSet[string]]::new() }
    if (-not $Visited.Add($GroupDN)) { return $CurrentDepth }  # cycle detection

    $maxDepth = $CurrentDepth
    $members = Get-ADGroupMember -Identity $GroupDN -ErrorAction SilentlyContinue |
        Where-Object { $_.objectClass -eq 'group' }

    foreach ($member in $members) {
        $depth = Get-GroupNestingDepth -GroupDN $member.DistinguishedName -CurrentDepth ($CurrentDepth + 1) -Visited $Visited
        if ($depth -gt $maxDepth) { $maxDepth = $depth }
    }
    return $maxDepth
}

Write-Host "`n=== Group Nesting Depth Audit ===" -ForegroundColor Cyan
Write-Host "Threshold: depth > $MaxNestingThreshold flagged | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$allGroups = Get-ADGroup -Filter * -SearchBase $SearchBase -Properties GroupScope, Members
$results   = @()
$count     = 0

Write-Host "Analyzing $($allGroups.Count) groups..." -ForegroundColor Gray

foreach ($group in $allGroups) {
    $count++
    if ($count % 50 -eq 0) { Write-Progress -Activity "Analyzing groups" -Status "$count / $($allGroups.Count)" -PercentComplete (($count / $allGroups.Count) * 100) }

    $depth = Get-GroupNestingDepth -GroupDN $group.DistinguishedName
    $memberCount = ($group.Members | Measure-Object).Count

    $results += [PSCustomObject]@{
        GroupName    = $group.Name
        Scope        = $group.GroupScope
        NestingDepth = $depth
        MemberCount  = $memberCount
        Flagged      = ($depth -gt $MaxNestingThreshold)
        DN           = $group.DistinguishedName
    }
}
Write-Progress -Activity "Analyzing groups" -Completed

$flagged  = $results | Where-Object { $_.Flagged } | Sort-Object NestingDepth -Descending
$universals = $results | Where-Object { $_.Scope -eq 'Universal' } | Sort-Object MemberCount -Descending

Write-Host "`nGROUPS WITH NESTING DEPTH > $MaxNestingThreshold (PAC token bloat risk):" -ForegroundColor Red
if ($flagged.Count -eq 0) {
    Write-Host "  [OK] No deeply nested groups found" -ForegroundColor Green
} else {
    $flagged | Select-Object -First 20 | ForEach-Object {
        Write-Host "  Depth $($_.NestingDepth): $($_.GroupName) ($($_.MemberCount) direct members)"
    }
}

Write-Host "`nTOP 10 UNIVERSAL GROUPS BY MEMBER COUNT (replication cost):" -ForegroundColor Yellow
$universals | Select-Object -First 10 | ForEach-Object {
    Write-Host "  $($_.MemberCount.ToString().PadLeft(5)) members: $($_.GroupName)"
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total groups:           $($allGroups.Count)"
Write-Host "Deep nesting (>$MaxNestingThreshold): $($flagged.Count)"
Write-Host "Universal groups:       $($universals.Count)"

$results | Sort-Object NestingDepth -Descending |
    Export-Csv -Path ".\GroupNestingAudit_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
Write-Host "Exported: GroupNestingAudit_$(Get-Date -Format 'yyyyMMdd').csv" -ForegroundColor Green
