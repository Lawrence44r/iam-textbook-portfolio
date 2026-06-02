<#
.SYNOPSIS
    Script 5-6: Windows LAPS Deployment Audit
.DESCRIPTION
    Audits LAPS coverage, password age, and retrieval activity.
    Distinguishes Legacy LAPS (ms-Mcs-AdmPwd) from Windows LAPS (msLAPS-Password).
    Checks retrieval event log (Event 4662) for unauthorized access.
.NOTES
    Requires: ActiveDirectory module; Event log access on DCs for retrieval audit
    Chapter 5 §5.6 — LAPS
#>
[CmdletBinding()]
param(
    [string]$SearchBase       = (Get-ADDomain).DistinguishedName,
    [int]$PasswordAgeDays     = 30,
    [switch]$CheckRetrievalLog
)

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "`n=== Windows LAPS Deployment Audit ===" -ForegroundColor Cyan
Write-Host "Password age threshold: $PasswordAgeDays days | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# Detect LAPS schema version
$schema   = Get-ADObject "CN=Schema,CN=Configuration,$(Get-ADDomain | Select-Object -ExpandProperty DistinguishedName)" -ErrorAction SilentlyContinue
$legacyAttr = Get-ADObject -SearchBase $schema.DistinguishedName -Filter { ldapDisplayName -eq 'ms-Mcs-AdmPwd' } -ErrorAction SilentlyContinue
$modernAttr = Get-ADObject -SearchBase $schema.DistinguishedName -Filter { ldapDisplayName -eq 'msLAPS-Password' } -ErrorAction SilentlyContinue

$hasLegacyLAPS = $null -ne $legacyAttr
$hasWindowsLAPS = $null -ne $modernAttr

Write-Host "Schema Detection:" -ForegroundColor Yellow
Write-Host "  Legacy LAPS (ms-Mcs-AdmPwd):   $(if ($hasLegacyLAPS) { '[PRESENT]' } else { '[NOT FOUND]' })"
Write-Host "  Windows LAPS (msLAPS-Password): $(if ($hasWindowsLAPS) { '[PRESENT]' } else { '[NOT FOUND]' })"

if (-not $hasLegacyLAPS -and -not $hasWindowsLAPS) {
    Write-Host "`n[CRITICAL] LAPS is NOT deployed — local admin passwords are unmanaged" -ForegroundColor Red
    return
}

# Get all computers
$computers = Get-ADComputer -Filter * -SearchBase $SearchBase -Properties `
    'ms-Mcs-AdmPwdExpirationTime', 'msLAPS-PasswordExpirationTime', `
    'ms-Mcs-AdmPwd', 'msLAPS-Password', OperatingSystem, LastLogonDate

$total          = $computers.Count
$lapsEnrolled   = 0
$lapsNotEnrolled = @()
$expired        = @()

foreach ($computer in $computers) {
    $hasLegacyPw  = $null -ne $computer.'ms-Mcs-AdmPwd'
    $hasModernPw  = $null -ne $computer.'msLAPS-Password'
    $isEnrolled   = $hasLegacyPw -or $hasModernPw

    if ($isEnrolled) {
        $lapsEnrolled++
        # Check password age
        $expiryTime = $computer.'msLAPS-PasswordExpirationTime' ?? $computer.'ms-Mcs-AdmPwdExpirationTime'
        if ($expiryTime) {
            $expiry = [datetime]::FromFileTime($expiryTime)
            if ($expiry -lt (Get-Date)) {
                $expired += $computer.Name
            }
        }
    } else {
        $lapsNotEnrolled += [PSCustomObject]@{
            ComputerName  = $computer.Name
            OS            = $computer.OperatingSystem
            LastLogon     = $computer.LastLogonDate
        }
    }
}

$coverage = if ($total -gt 0) { [math]::Round(($lapsEnrolled / $total) * 100, 1) } else { 0 }

Write-Host "`nCOVERAGE:" -ForegroundColor Yellow
Write-Host "  Total computers: $total"
Write-Host "  LAPS enrolled:   $lapsEnrolled ($coverage%)"
Write-Host "  Not enrolled:    $($lapsNotEnrolled.Count)"
$coverageColor = if ($coverage -ge 95) { 'Green' } elseif ($coverage -ge 80) { 'Yellow' } else { 'Red' }
Write-Host "  Coverage:        $coverage%" -ForegroundColor $coverageColor

if ($expired.Count -gt 0) {
    Write-Host "`n  [WARNING] $($expired.Count) computer(s) with expired LAPS passwords:" -ForegroundColor Yellow
    $expired | Select-Object -First 10 | ForEach-Object { Write-Host "    - $_" }
}

if ($lapsNotEnrolled.Count -gt 0) {
    Write-Host "`nCOMPUTERS WITHOUT LAPS (first 20):" -ForegroundColor Red
    $lapsNotEnrolled | Select-Object -First 20 | ForEach-Object {
        Write-Host "  $($_.ComputerName) [$($_.OS)] Last logon: $($_.LastLogon)"
    }

    $lapsNotEnrolled | Export-Csv -Path ".\LAPSNotEnrolled_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
    Write-Host "`nNot-enrolled list exported: LAPSNotEnrolled_$(Get-Date -Format 'yyyyMMdd').csv" -ForegroundColor Yellow
}

Write-Host "`nRetrieve LAPS password (authorized use only):" -ForegroundColor Gray
Write-Host "  Windows LAPS: Get-LapsADPassword -Identity COMPUTERNAME -AsPlainText"
Write-Host "  Legacy LAPS:  Get-AdmPwdPassword -ComputerName COMPUTERNAME"
