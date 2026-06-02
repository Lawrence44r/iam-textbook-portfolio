<#
.SYNOPSIS
    Script 8-9: Graph API Delta Query for Incremental Change Tracking
.DESCRIPTION
    Tracks incremental user/group changes using Graph delta queries.
    Stores delta link between runs; next run fetches only changes since last delta.
    Use case: IGA integration, change audit, replication monitoring.
.NOTES
    Requires: Microsoft.Graph module
    Permissions: User.Read.All, Group.Read.All
    Chapter 8 §8.6 — Graph API Patterns (Delta, Batch, Throttling)
#>
[CmdletBinding()]
param(
    [string]$DeltaLinkFile = ".\graph-delta-link.json",
    [ValidateSet('Users','Groups')][string]$Resource = 'Users',
    [string]$OutputPath = ".\GraphDeltaChanges_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
)

Import-Module Microsoft.Graph.Users  -ErrorAction Stop
Import-Module Microsoft.Graph.Groups -ErrorAction Stop

try { Get-MgContext -ErrorAction Stop | Out-Null } catch {
    Connect-MgGraph -Scopes "User.Read.All","Group.Read.All"
}

Write-Host "`n=== Graph API Delta Query — $Resource ===" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$deltaState  = @{}
$savedDeltas = @{}

if (Test-Path $DeltaLinkFile) {
    $savedDeltas = Get-Content $DeltaLinkFile | ConvertFrom-Json -AsHashtable
}

$changes     = @()
$nextLink    = $null
$newDeltaLink = $null

if ($savedDeltas.ContainsKey($Resource)) {
    # Incremental: use saved delta link
    $deltaLink = $savedDeltas[$Resource]
    Write-Host "Using saved delta link (incremental query)..." -ForegroundColor Gray
    Write-Host "Delta link: $($deltaLink.Substring(0, [Math]::Min(80, $deltaLink.Length)))..."

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $deltaLink
        $changes  += $response.value
        while ($response.'@odata.nextLink') {
            $response = Invoke-MgGraphRequest -Method GET -Uri $response.'@odata.nextLink'
            $changes += $response.value
        }
        $newDeltaLink = $response.'@odata.deltaLink'
    } catch {
        Write-Host "[WARNING] Delta link expired or invalid — performing full sync" -ForegroundColor Yellow
        $savedDeltas.Remove($Resource)
    }
}

if (-not $savedDeltas.ContainsKey($Resource)) {
    # Initial full sync
    Write-Host "Performing initial full sync (no saved delta link)..." -ForegroundColor Gray
    $apiPath = "https://graph.microsoft.com/v1.0/$($Resource.ToLower())/delta?`$select=displayName,userPrincipalName,accountEnabled,jobTitle,department,assignedLicenses"

    $response = Invoke-MgGraphRequest -Method GET -Uri $apiPath
    $changes += $response.value
    while ($response.'@odata.nextLink') {
        $response = Invoke-MgGraphRequest -Method GET -Uri $response.'@odata.nextLink'
        $changes += $response.value
    }
    $newDeltaLink = $response.'@odata.deltaLink'
    Write-Host "Full sync complete. $($changes.Count) objects." -ForegroundColor Green
}

# Save new delta link for next run
if ($newDeltaLink) {
    $savedDeltas[$Resource] = $newDeltaLink
    $savedDeltas | ConvertTo-Json | Out-File $DeltaLinkFile -Encoding UTF8
    Write-Host "Delta link saved for next incremental query." -ForegroundColor Green
}

# Process changes
$created  = @($changes | Where-Object { -not $_.'@removed' -and $_.'createdDateTime' })
$modified = @($changes | Where-Object { -not $_.'@removed' -and -not $_.'createdDateTime' })
$deleted  = @($changes | Where-Object { $_.'@removed' })

Write-Host "`nChanges since last delta:" -ForegroundColor Yellow
Write-Host "  Created:  $($created.Count)"
Write-Host "  Modified: $($modified.Count)"
Write-Host "  Deleted:  $($deleted.Count)"

if ($deleted.Count -gt 0) {
    Write-Host "`nDeleted objects:" -ForegroundColor Red
    $deleted | Select-Object -First 10 | ForEach-Object {
        Write-Host "  Deleted: $($_.id) (reason: $($_.'@removed'.reason))"
    }
}

if ($changes.Count -gt 0) {
    $changes | ConvertTo-Json -Depth 3 | Out-File $OutputPath -Encoding UTF8
    Write-Host "`nChanges exported: $OutputPath" -ForegroundColor Green
} else {
    Write-Host "`n[OK] No changes detected since last delta query." -ForegroundColor Green
}
