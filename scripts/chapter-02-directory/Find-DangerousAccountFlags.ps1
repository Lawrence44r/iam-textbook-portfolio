<#
.SYNOPSIS
    Script 2-2: Dangerous userAccountControl Flag Audit
.DESCRIPTION
    Finds all accounts with dangerous userAccountControl bitmask flags:
    - TRUSTED_FOR_DELEGATION (unconstrained delegation, flag 0x80000)
    - PASSWD_NOTREQD (no password required, flag 0x20)
    - DONT_EXPIRE_PASSWORD (flag 0x10000)
    - TRUSTED_TO_AUTH_FOR_DELEGATION (constrained with protocol transition, flag 0x1000000)
.NOTES
    Requires: ActiveDirectory module
    Chapter 2 §2.4 — Kerberos Attack Taxonomy
#>
[CmdletBinding()]
param(
    [string]$SearchBase = (Get-ADDomain).DistinguishedName,
    [string]$OutputPath = ".\DangerousAccountFlags_$(Get-Date -Format 'yyyyMMdd').csv"
)

Import-Module ActiveDirectory -ErrorAction Stop

# userAccountControl flag constants
$UAC_FLAGS = @{
    PASSWD_NOTREQD                   = 0x20
    PASSWD_CANT_CHANGE               = 0x40
    DONT_EXPIRE_PASSWORD             = 0x10000
    TRUSTED_FOR_DELEGATION           = 0x80000     # Unconstrained delegation
    TRUSTED_TO_AUTH_FOR_DELEGATION   = 0x1000000   # Constrained w/ protocol transition
    NOT_DELEGATED                    = 0x100000
    USE_DES_KEY_ONLY                 = 0x200000    # DES-only Kerberos (legacy weak)
}

Write-Host "`n=== Dangerous userAccountControl Flag Audit ===" -ForegroundColor Cyan
Write-Host "SearchBase: $SearchBase`n"

$allAccounts = Get-ADUser -Filter * -SearchBase $SearchBase -Properties `
    userAccountControl, LastLogonDate, MemberOf, DistinguishedName, Enabled `
    -ErrorAction Stop

$results = @()

foreach ($account in $allAccounts) {
    $uac = $account.userAccountControl
    $findings = @()

    if ($uac -band $UAC_FLAGS.TRUSTED_FOR_DELEGATION) {
        $findings += "UNCONSTRAINED_DELEGATION"
    }
    if ($uac -band $UAC_FLAGS.PASSWD_NOTREQD) {
        $findings += "PASSWD_NOTREQD"
    }
    if ($uac -band $UAC_FLAGS.DONT_EXPIRE_PASSWORD) {
        $findings += "DONT_EXPIRE_PASSWORD"
    }
    if ($uac -band $UAC_FLAGS.TRUSTED_TO_AUTH_FOR_DELEGATION) {
        $findings += "CONSTRAINED_DELEGATION_WITH_PROTOCOL_TRANSITION"
    }
    if ($uac -band $UAC_FLAGS.USE_DES_KEY_ONLY) {
        $findings += "DES_KEY_ONLY"
    }

    if ($findings.Count -gt 0) {
        $groupCount = ($account.MemberOf | Measure-Object).Count
        $result = [PSCustomObject]@{
            SamAccountName = $account.SamAccountName
            Enabled        = $account.Enabled
            Flags          = $findings -join '; '
            UAC_Value      = $uac
            LastLogonDate  = $account.LastLogonDate
            GroupCount     = $groupCount
            DN             = $account.DistinguishedName
            Risk           = if ($findings -contains 'UNCONSTRAINED_DELEGATION') { 'CRITICAL' }
                             elseif ($findings -contains 'CONSTRAINED_DELEGATION_WITH_PROTOCOL_TRANSITION') { 'HIGH' }
                             else { 'MEDIUM' }
        }
        $results += $result

        $color = switch ($result.Risk) {
            'CRITICAL' { 'Red' }
            'HIGH'     { 'Yellow' }
            default    { 'White' }
        }
        Write-Host "[$($result.Risk)] $($account.SamAccountName)" -ForegroundColor $color
        Write-Host "  Flags: $($findings -join ', ')" -ForegroundColor Gray
        Write-Host "  Last Logon: $($account.LastLogonDate)  Groups: $groupCount"
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total accounts scanned: $($allAccounts.Count)"
Write-Host "Accounts with dangerous flags: $($results.Count)"
Write-Host "  CRITICAL (unconstrained delegation): $(($results | Where-Object {$_.Risk -eq 'CRITICAL'}).Count)"
Write-Host "  HIGH (protocol transition): $(($results | Where-Object {$_.Risk -eq 'HIGH'}).Count)"
Write-Host "  MEDIUM: $(($results | Where-Object {$_.Risk -eq 'MEDIUM'}).Count)"

if ($results.Count -gt 0) {
    $results | Sort-Object Risk, SamAccountName | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-Host "`nExported: $OutputPath" -ForegroundColor Green
}
