<#
.SYNOPSIS
    Script 6-3: CAE Verification and Emergency Session Revocation
.DESCRIPTION
    Verifies CAE (Continuous Access Evaluation) is functioning.
    Measures % of sign-ins using modern auth (CAE-capable) vs. legacy auth.
    Tests emergency session revocation latency for a specified test user.
.NOTES
    Requires: Microsoft.Graph module
    Permissions: AuditLog.Read.All, User.ReadWrite.All (for revocation test)
    Chapter 6 §6.5 — CAE Deep Dive; Chapter 10 §10.3
#>
[CmdletBinding()]
param(
    [string]$TestUserUPN = "",   # UPN of test account for revocation latency test
    [int]$LookbackDays   = 7
)

Import-Module Microsoft.Graph.Reports -ErrorAction Stop
Import-Module Microsoft.Graph.Users   -ErrorAction Stop

try { Get-MgContext -ErrorAction Stop | Out-Null } catch {
    Connect-MgGraph -Scopes "AuditLog.Read.All","User.ReadWrite.All","Directory.Read.All"
}

Write-Host "`n=== CAE Coverage Analysis and Revocation Test ===" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# --- Sign-in Analysis ---
Write-Host "1. SIGN-IN AUTH TYPE BREAKDOWN (last $LookbackDays days)" -ForegroundColor Yellow
$since = (Get-Date).AddDays(-$LookbackDays).ToString('yyyy-MM-dd')

try {
    $signins = Get-MgAuditLogSignIn -Filter "createdDateTime ge $since" -Top 500 -ErrorAction Stop

    $modernAuth = $signins | Where-Object { $_.ClientAppUsed -notin @('Exchange ActiveSync','IMAP4','MAPI','SMTP','POP3','Other clients') }
    $legacyAuth = $signins | Where-Object { $_.ClientAppUsed -in  @('Exchange ActiveSync','IMAP4','MAPI','SMTP','POP3','Other clients') }

    $modernPct = if ($signins.Count -gt 0) { [math]::Round(($modernAuth.Count / $signins.Count) * 100, 1) } else { 0 }

    Write-Host "  Total sign-ins sampled: $($signins.Count)"
    Write-Host "  Modern auth (CAE-capable): $($modernAuth.Count) ($modernPct%)" -ForegroundColor $(if ($modernPct -ge 95) { 'Green' } else { 'Yellow' })
    Write-Host "  Legacy auth (NOT CAE):     $($legacyAuth.Count) ($([math]::Round(100 - $modernPct, 1))%)"

    if ($legacyAuth.Count -gt 0) {
        Write-Host "`n  Legacy auth clients still in use:" -ForegroundColor Yellow
        $legacyAuth | Group-Object ClientAppUsed | Sort-Object Count -Descending | Select-Object -First 10 |
            ForEach-Object { Write-Host "    $($_.Count.ToString().PadLeft(5)) - $($_.Name)" }
        Write-Host "`n  CAE is ineffective for legacy auth clients." -ForegroundColor Yellow
        Write-Host "  Remediation: Enforce modern auth via CA policy (Block legacy auth, Tier B-01)" -ForegroundColor Yellow
    }

    # CAE-specific claim check
    $caeSignins = $signins | Where-Object { $_.AuthenticationDetails.AuthenticationMethod -match 'cp1' }
    Write-Host "`n  Sign-ins with CAE cp1 claim: $($caeSignins.Count) (direct evidence of CAE negotiation)"

} catch {
    Write-Host "  [SKIP] Cannot query sign-in logs: $_" -ForegroundColor Gray
}

# --- Revocation Latency Test ---
if ($TestUserUPN) {
    Write-Host "`n2. EMERGENCY REVOCATION LATENCY TEST" -ForegroundColor Yellow
    Write-Host "   Test user: $TestUserUPN"
    Write-Host "   [WARNING] This revokes ALL refresh tokens for the test user immediately!" -ForegroundColor Red

    $confirm = Read-Host "   Type 'CONFIRM' to proceed with revocation test"
    if ($confirm -eq 'CONFIRM') {
        $user = Get-MgUser -UserId $TestUserUPN -ErrorAction Stop
        $startTime = Get-Date
        Invoke-MgInvalidateAllUserRefreshToken -UserId $user.Id
        Write-Host "   Revocation issued at: $($startTime.ToString('HH:mm:ss'))" -ForegroundColor Green
        Write-Host "   Measure time until the user's OWA or Teams session prompts for re-auth." -ForegroundColor Gray
        Write-Host "   Expected for CAE-enabled clients: < 60 seconds"
        Write-Host "   Expected for non-CAE clients:     up to 28 hours (next token validation)"
        Write-Host "`n   Record the result as your CAE revocation baseline metric." -ForegroundColor Cyan
    } else {
        Write-Host "   Test skipped." -ForegroundColor Gray
    }
} else {
    Write-Host "`n2. REVOCATION LATENCY TEST: Skipped (provide -TestUserUPN to enable)" -ForegroundColor Gray
}

Write-Host "`nCAE Key Facts:" -ForegroundColor Gray
Write-Host "  - CAE-capable resources: Exchange Online, SharePoint, Teams, Graph API"
Write-Host "  - CAE token lifetime: up to 28 hours (extended from 60-90 min)"
Write-Host "  - CAE revocation events: password change, location change, account disable, risk elevation"
Write-Host "  - Token claim: 'cp1' capability in access token required by resource server"
