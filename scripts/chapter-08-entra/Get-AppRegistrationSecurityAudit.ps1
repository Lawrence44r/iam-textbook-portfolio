<#
.SYNOPSIS
    Script 8-3: Application Registration Security Audit
.DESCRIPTION
    Audits all App Registrations for security hygiene issues.
    Flags: expiring/expired client secrets, no owners, multi-tenant apps with high-privilege permissions.
.NOTES
    Requires: Microsoft.Graph module
    Permissions: Application.Read.All, Directory.Read.All
    Chapter 8 §8.3 — App Registration vs. Enterprise App
#>
[CmdletBinding()]
param(
    [int]$ExpiryWarnDays = 30
)

Import-Module Microsoft.Graph.Applications -ErrorAction Stop
try { Get-MgContext -ErrorAction Stop | Out-Null } catch {
    Connect-MgGraph -Scopes "Application.Read.All","Directory.Read.All"
}

Write-Host "`n=== App Registration Security Audit ===" -ForegroundColor Cyan
Write-Host "Expiry warn threshold: $ExpiryWarnDays days | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$apps = Get-MgApplication -All -Property "Id,DisplayName,AppId,SignInAudience,PasswordCredentials,KeyCredentials,Owners,RequiredResourceAccess,CreatedDateTime"

$results = @()
$now     = Get-Date

foreach ($app in $apps) {
    $findings = @()

    # Check 1: Client secrets expiring soon or expired
    foreach ($secret in $app.PasswordCredentials) {
        if ($secret.EndDateTime -lt $now) {
            $findings += "EXPIRED_SECRET: '$($secret.DisplayName)' expired $($secret.EndDateTime.ToString('yyyy-MM-dd'))"
        } elseif ($secret.EndDateTime -lt $now.AddDays($ExpiryWarnDays)) {
            $daysLeft = ($secret.EndDateTime - $now).Days
            $findings += "EXPIRING_SECRET: '$($secret.DisplayName)' expires in $daysLeft days ($($secret.EndDateTime.ToString('yyyy-MM-dd')))"
        }
    }

    # Check 2: No owners (orphaned application)
    $owners = Get-MgApplicationOwner -ApplicationId $app.Id -ErrorAction SilentlyContinue
    if ($owners.Count -eq 0) {
        $findings += "NO_OWNERS: Application has no designated owner — orphaned app risk"
    }

    # Check 3: Multi-tenant application (sign-in audience includes external)
    $isMultiTenant = $app.SignInAudience -in @('AzureADMultipleOrgs','AzureADandPersonalMicrosoftAccount','PersonalMicrosoftAccount')
    if ($isMultiTenant) {
        $findings += "MULTI_TENANT: SignInAudience=$($app.SignInAudience) — accessible from external tenants"
    }

    # Check 4: High-privilege Application permissions
    $highPrivPerms = @('RoleManagement.ReadWrite.Directory','Directory.ReadWrite.All','Mail.ReadWrite','Files.ReadWrite.All','User.ReadWrite.All')
    foreach ($resource in $app.RequiredResourceAccess) {
        foreach ($perm in $resource.ResourceAccess) {
            if ($perm.Type -eq 'Role') {  # Application permission (not delegated)
                # Check if it's a known high-priv permission (simplified — in prod, resolve GUID to scope name)
                $findings += "APP_PERMISSION: Application permission GUID $($perm.Id) (verify: may be high-priv)"
            }
        }
    }

    $risk = if ($findings | Where-Object { $_ -match 'EXPIRED|NO_OWNERS' }) { 'HIGH' }
            elseif ($findings | Where-Object { $_ -match 'EXPIRING|MULTI_TENANT|APP_PERMISSION' }) { 'MEDIUM' }
            elseif ($findings.Count -gt 0) { 'LOW' }
            else { 'OK' }

    if ($risk -ne 'OK') {
        $color = switch ($risk) { 'HIGH' { 'Red' } 'MEDIUM' { 'Yellow' } default { 'White' } }
        Write-Host "[$risk] $($app.DisplayName) (AppId: $($app.AppId))" -ForegroundColor $color
        $findings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

        $results += [PSCustomObject]@{
            DisplayName    = $app.DisplayName
            AppId          = $app.AppId
            Risk           = $risk
            SignInAudience = $app.SignInAudience
            OwnerCount     = $owners.Count
            SecretCount    = $app.PasswordCredentials.Count
            CertCount      = $app.KeyCredentials.Count
            Findings       = $findings -join ' | '
            CreatedDate    = $app.CreatedDateTime
        }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Apps scanned: $($apps.Count)"
Write-Host "With findings:"
Write-Host "  HIGH:   $(($results | Where-Object {$_.Risk -eq 'HIGH'}).Count)"
Write-Host "  MEDIUM: $(($results | Where-Object {$_.Risk -eq 'MEDIUM'}).Count)"

$results | Sort-Object Risk, DisplayName | Export-Csv -Path ".\AppRegistrationAudit_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
Write-Host "`nExported: AppRegistrationAudit_$(Get-Date -Format 'yyyyMMdd').csv" -ForegroundColor Green
