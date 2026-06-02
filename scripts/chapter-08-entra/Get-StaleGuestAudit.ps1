<#
.SYNOPSIS
    Script 8-5: Stale B2B Guest Audit
.DESCRIPTION
    Finds B2B guests with no recent activity, unredeemed invitations, or floating access.
    Stale guests are an attack surface: supply chain compromise can leverage dormant accounts.
.NOTES
    Requires: Microsoft.Graph module
    Permissions: User.Read.All, AuditLog.Read.All
    Chapter 8 §8.4 — B2B Guest Governance
#>
[CmdletBinding()]
param(
    [int]$StaleLastSignInDays = 90,
    [string]$OutputPath = ".\StaleGuestAudit_$(Get-Date -Format 'yyyyMMdd').csv"
)

Import-Module Microsoft.Graph.Users -ErrorAction Stop
try { Get-MgContext -ErrorAction Stop | Out-Null } catch {
    Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All","Directory.Read.All"
}

Write-Host "`n=== Stale B2B Guest Audit ===" -ForegroundColor Cyan
Write-Host "Stale threshold: $StaleLastSignInDays days | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$guests = Get-MgUser -Filter "userType eq 'Guest'" -All `
    -Property "Id,DisplayName,UserPrincipalName,Mail,ExternalUserState,ExternalUserStateChangeDateTime,SignInActivity,CreatedDateTime,CompanyName" `
    -ErrorAction Stop

Write-Host "Total B2B guests: $($guests.Count)`n"

$staleGuests = @()
$cutoff      = (Get-Date).AddDays(-$StaleLastSignInDays)

foreach ($guest in $guests) {
    $findings  = @()
    $lastSignIn = $null

    # Get sign-in activity
    try {
        $signInActivity = $guest.SignInActivity
        $lastSignIn = $signInActivity.LastSignInDateTime
    } catch {}

    # Check 1: Unredeemed invitation
    if ($guest.ExternalUserState -eq 'PendingAcceptance') {
        $daysPending = ((Get-Date) - $guest.ExternalUserStateChangeDateTime).Days
        $findings += "PENDING_ACCEPTANCE: Invitation unredeemed for $daysPending days"
    }

    # Check 2: No recent sign-in
    if ($null -eq $lastSignIn -and $guest.CreatedDateTime -lt $cutoff) {
        $findings += "NO_SIGNIN: Never signed in, account created $($guest.CreatedDateTime.ToString('yyyy-MM-dd'))"
    } elseif ($lastSignIn -ne $null -and $lastSignIn -lt $cutoff) {
        $daysSince = ((Get-Date) - $lastSignIn).Days
        $findings += "STALE_SIGNIN: Last sign-in $daysSince days ago ($($lastSignIn.ToString('yyyy-MM-dd')))"
    }

    # Check 3: Group membership (floating access if no groups)
    try {
        $groups = Get-MgUserMemberOf -UserId $guest.Id -ErrorAction SilentlyContinue
        if ($groups.Count -eq 0) {
            $findings += "NO_GROUP_MEMBERSHIP: Guest has no group assignments — floating access"
        }
    } catch {}

    if ($findings.Count -gt 0) {
        $risk = if ($findings | Where-Object { $_ -match 'PENDING|NO_SIGNIN' }) { 'HIGH' } else { 'MEDIUM' }
        $color = if ($risk -eq 'HIGH') { 'Red' } else { 'Yellow' }

        Write-Host "[$risk] $($guest.DisplayName) ($($guest.Mail ?? $guest.UserPrincipalName))" -ForegroundColor $color
        $findings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

        $staleGuests += [PSCustomObject]@{
            DisplayName       = $guest.DisplayName
            Email             = $guest.Mail ?? $guest.UserPrincipalName
            Company           = $guest.CompanyName
            ExternalUserState = $guest.ExternalUserState
            LastSignIn        = $lastSignIn
            CreatedDate       = $guest.CreatedDateTime
            Risk              = $risk
            Findings          = $findings -join ' | '
            RecommendedAction = if ($findings | Where-Object { $_ -match 'PENDING' }) { 'Remove invitation' }
                               elseif ($findings | Where-Object { $_ -match 'NO_SIGNIN' }) { 'Review with sponsor; remove if unneeded' }
                               else { 'Disable and review with sponsor within 30 days' }
        }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total guests:       $($guests.Count)"
Write-Host "Stale / at-risk:    $($staleGuests.Count)"
Write-Host "  HIGH risk:        $(($staleGuests | Where-Object {$_.Risk -eq 'HIGH'}).Count)"
Write-Host "  MEDIUM risk:      $(($staleGuests | Where-Object {$_.Risk -eq 'MEDIUM'}).Count)"

if ($staleGuests.Count -gt 0) {
    $staleGuests | Sort-Object Risk, DisplayName | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-Host "`nExported: $OutputPath" -ForegroundColor Green
    Write-Host "Recommended: Review with access sponsors; remove all pending and no-signin accounts." -ForegroundColor Yellow
} else {
    Write-Host "[CLEAN] No stale guest accounts found." -ForegroundColor Green
}
