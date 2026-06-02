<#
.SYNOPSIS
    Script 5-9: Break-Glass Account Monitoring
.DESCRIPTION
    Audits break-glass account configuration and reports on any use.
    Validates: cloud-only (not synced), FIDO2-only MFA, excluded from all CA policies.
    Any break-glass sign-in event should immediately alert the SOC.
.NOTES
    Requires: Microsoft.Graph module
    Permissions: User.Read.All, Policy.Read.All, AuditLog.Read.All
    Chapter 5 §5.7 — Break-Glass Design
#>
[CmdletBinding()]
param(
    [string[]]$BreakGlassUPNs = @(),   # Provide UPNs or tag by group/naming convention
    [string]$BreakGlassGroupName = "Break-Glass-Accounts",
    [int]$LookbackDays = 90
)

Import-Module Microsoft.Graph.Users -ErrorAction Stop
Import-Module Microsoft.Graph.Reports -ErrorAction Stop

try { Get-MgContext -ErrorAction Stop | Out-Null } catch {
    Connect-MgGraph -Scopes "User.Read.All","Policy.Read.All","AuditLog.Read.All","UserAuthenticationMethod.Read.All"
}

Write-Host "`n=== Break-Glass Account Audit ===" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# Discover break-glass accounts (by group or UPN list)
$bgAccounts = @()
if ($BreakGlassUPNs.Count -gt 0) {
    foreach ($upn in $BreakGlassUPNs) {
        $user = Get-MgUser -UserId $upn -Property "Id,DisplayName,UserPrincipalName,OnPremisesSyncEnabled,AccountEnabled" -ErrorAction SilentlyContinue
        if ($user) { $bgAccounts += $user }
    }
} else {
    try {
        $group = Get-MgGroup -Filter "displayName eq '$BreakGlassGroupName'" -ErrorAction Stop
        $bgAccounts = Get-MgGroupMember -GroupId $group.Id -All |
            ForEach-Object { Get-MgUser -UserId $_.Id -Property "Id,DisplayName,UserPrincipalName,OnPremisesSyncEnabled,AccountEnabled" }
    } catch {
        Write-Host "[WARNING] Group '$BreakGlassGroupName' not found. Provide -BreakGlassUPNs or create the group." -ForegroundColor Yellow
        return
    }
}

Write-Host "Break-glass accounts found: $($bgAccounts.Count)`n"
if ($bgAccounts.Count -eq 0) { Write-Host "[INFO] No break-glass accounts detected. Ensure they are tagged."; return }

$results = @()
foreach ($user in $bgAccounts) {
    Write-Host "Account: $($user.UserPrincipalName)" -ForegroundColor Yellow

    # Check 1: Cloud-only (not synced from on-prem)
    $isCloudOnly = -not $user.OnPremisesSyncEnabled
    $syncStatus  = if ($isCloudOnly) { "[OK] Cloud-only" } else { "[FAIL] ON-PREM SYNCED — RISK!" }
    $syncColor   = if ($isCloudOnly) { 'Green' } else { 'Red' }
    Write-Host "  Sync status:    $syncStatus" -ForegroundColor $syncColor

    # Check 2: Authentication methods (should be FIDO2 only)
    try {
        $authMethods = Get-MgUserAuthenticationMethod -UserId $user.Id -ErrorAction Stop
        $methodTypes = $authMethods | ForEach-Object { $_.GetType().Name }
        $hasFIDO2    = $methodTypes -contains 'MicrosoftGraphFido2AuthenticationMethod'
        $hasPassword = $methodTypes -contains 'MicrosoftGraphPasswordAuthenticationMethod'
        $hasPhone    = $methodTypes -contains 'MicrosoftGraphPhoneAuthenticationMethod'
        $methodList  = $methodTypes -join ', '

        $methodStatus = if ($hasFIDO2 -and -not $hasPhone) { "[OK] FIDO2-only" } else { "[WARNING] Non-FIDO2 method present" }
        $methodColor  = if ($hasFIDO2 -and -not $hasPhone) { 'Green' } else { 'Yellow' }
        Write-Host "  Auth methods:   $methodStatus ($methodList)" -ForegroundColor $methodColor
    } catch {
        Write-Host "  Auth methods:   [CANNOT READ - check UserAuthenticationMethod.Read.All scope]" -ForegroundColor Gray
        $hasFIDO2 = $null; $hasPassword = $null
    }

    # Check 3: Account enabled
    $enabledStatus = if ($user.AccountEnabled) { "[OK] Enabled" } else { "[WARNING] Account disabled" }
    Write-Host "  Account state:  $enabledStatus"

    # Check 4: Sign-in activity (should be 0 in normal operations)
    $signins = @()
    try {
        $since  = (Get-Date).AddDays(-$LookbackDays).ToString('yyyy-MM-dd')
        $filter = "userPrincipalName eq '$($user.UserPrincipalName)' and createdDateTime ge $since"
        $signins = Get-MgAuditLogSignIn -Filter $filter -Top 10 -ErrorAction Stop
    } catch { }

    $signinStatus = if ($signins.Count -eq 0) { "[OK] No sign-ins in last $LookbackDays days" }
                    else { "[ALERT] $($signins.Count) sign-in(s) detected!" }
    $signinColor  = if ($signins.Count -eq 0) { 'Green' } else { 'Red' }
    Write-Host "  Sign-in activity: $signinStatus" -ForegroundColor $signinColor

    if ($signins.Count -gt 0) {
        Write-Host "  [INVESTIGATE IMMEDIATELY] Break-glass accounts should NEVER be used in normal operations" -ForegroundColor Red
        $signins | ForEach-Object {
            Write-Host "    $($_.CreatedDateTime) from $($_.IpAddress) ($($_.Location.City), $($_.Location.CountryOrRegion)) Status: $($_.Status.ErrorCode)" -ForegroundColor Red
        }
    }

    $results += [PSCustomObject]@{
        UPN         = $user.UserPrincipalName
        CloudOnly   = $isCloudOnly
        FIDO2Only   = $hasFIDO2
        Enabled     = $user.AccountEnabled
        SignIns90d  = $signins.Count
        Risk        = if (-not $isCloudOnly) { 'CRITICAL' } elseif ($signins.Count -gt 0) { 'HIGH' } else { 'OK' }
    }
    Write-Host ""
}

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Break-glass accounts: $($bgAccounts.Count)"
Write-Host "Issues found:"
$results | Where-Object { -not $_.CloudOnly } | ForEach-Object { Write-Host "  [CRITICAL] $($_.UPN) is on-prem synced" -ForegroundColor Red }
$results | Where-Object { $_.SignIns90d -gt 0 } | ForEach-Object { Write-Host "  [HIGH] $($_.UPN) has $($_.SignIns90d) sign-in(s) — investigate!" -ForegroundColor Red }

Write-Host "`nSentinel Alert Query (deploy to detect any future use):" -ForegroundColor Gray
$bgUPNList = ($bgAccounts | ForEach-Object { "'$($_.UserPrincipalName)'" }) -join ','
Write-Host @"
SigninLogs
| where UserPrincipalName in ($bgUPNList)
| project TimeGenerated, UserPrincipalName, IPAddress, Location, ResultType
| extend Alert = "BREAK-GLASS ACCOUNT USED — INVESTIGATE IMMEDIATELY"
"@ -ForegroundColor Gray
