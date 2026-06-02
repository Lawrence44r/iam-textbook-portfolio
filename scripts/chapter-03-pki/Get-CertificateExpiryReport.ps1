<#
.SYNOPSIS
    Script 3-7: Certificate Expiry Monitoring
.DESCRIPTION
    Monitors all certificates issued by enterprise CAs for approaching expiry.
    Warn threshold: 60 days. Critical threshold: 30 days.
    Exports CSV for ticketing integration.
.NOTES
    Requires: certutil.exe (built-in Windows), ADCS CA database access
    Chapter 3 §3.5 — Certificate Lifecycle
#>
[CmdletBinding()]
param(
    [string]$CAName         = "",   # Leave empty to query all enrolled CAs
    [int]$WarnDays          = 60,
    [int]$CriticalDays      = 30,
    [string]$OutputPath     = ".\CertExpiryReport_$(Get-Date -Format 'yyyyMMdd').csv"
)

Write-Host "`n=== Certificate Expiry Report ===" -ForegroundColor Cyan
Write-Host "Warn: $WarnDays days | Critical: $CriticalDays days | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# Use certutil to query issued certs
# This runs on the CA server or with remote CA access
$now       = Get-Date
$results   = @()

try {
    # Get all issued (not revoked) certificates from certutil database
    $certutilOutput = if ($CAName) {
        certutil -config $CAName -view -restrict "Disposition=20" -out "RequesterName,CommonName,NotBefore,NotAfter,SerialNumber" 2>&1
    } else {
        certutil -view -restrict "Disposition=20" -out "RequesterName,CommonName,NotBefore,NotAfter,SerialNumber" 2>&1
    }

    # Parse certutil output (text format)
    $currentCert = @{}
    foreach ($line in $certutilOutput) {
        if ($line -match 'Requester Name:\s+(.+)') { $currentCert.Requester = $Matches[1].Trim() }
        if ($line -match 'Subject:\s+CN=(.+)') { $currentCert.CN = $Matches[1].Trim() }
        if ($line -match 'Not After:\s+(.+)') {
            $expiry = [datetime]::Parse($Matches[1].Trim())
            $currentCert.NotAfter = $expiry
            $daysLeft = ($expiry - $now).Days

            $status = if ($daysLeft -lt 0) { 'EXPIRED' }
                      elseif ($daysLeft -lt $CriticalDays) { 'CRITICAL' }
                      elseif ($daysLeft -lt $WarnDays) { 'WARNING' }
                      else { 'OK' }

            if ($status -ne 'OK') {
                $results += [PSCustomObject]@{
                    Status      = $status
                    DaysLeft    = $daysLeft
                    Expiry      = $expiry.ToString('yyyy-MM-dd')
                    CommonName  = $currentCert.CN
                    Requester   = $currentCert.Requester
                    Serial      = $currentCert.Serial
                }
                $color = switch ($status) { 'EXPIRED' { 'Red' } 'CRITICAL' { 'Red' } 'WARNING' { 'Yellow' } default { 'White' } }
                Write-Host "[$status] $($currentCert.CN) expires $($expiry.ToString('yyyy-MM-dd')) ($daysLeft days)" -ForegroundColor $color
            }
            $currentCert = @{}
        }
        if ($line -match 'Serial Number:\s+(.+)') { $currentCert.Serial = $Matches[1].Trim() }
    }
} catch {
    Write-Host "[ERROR] Could not query CA database: $_" -ForegroundColor Red
    Write-Host "Run this script on the CA server or with -CAName 'SERVER\CA-Name'" -ForegroundColor Yellow

    # Fallback: scan local machine certificate stores
    Write-Host "`nFalling back to local machine certificate store scan..." -ForegroundColor Gray
    Get-ChildItem Cert:\LocalMachine -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_ -is [System.Security.Cryptography.X509Certificates.X509Certificate2] } |
        ForEach-Object {
            $daysLeft = ($_.NotAfter - $now).Days
            $status = if ($daysLeft -lt 0) { 'EXPIRED' }
                      elseif ($daysLeft -lt $CriticalDays) { 'CRITICAL' }
                      elseif ($daysLeft -lt $WarnDays) { 'WARNING' }
                      else { 'OK' }

            if ($status -ne 'OK') {
                $results += [PSCustomObject]@{
                    Status     = $status
                    DaysLeft   = $daysLeft
                    Expiry     = $_.NotAfter.ToString('yyyy-MM-dd')
                    CommonName = $_.Subject
                    Requester  = 'LocalMachine'
                    Serial     = $_.SerialNumber
                }
                $color = if ($status -eq 'EXPIRED' -or $status -eq 'CRITICAL') { 'Red' } else { 'Yellow' }
                Write-Host "[$status] $($_.Subject) expires $($_.NotAfter.ToString('yyyy-MM-dd')) ($daysLeft days)" -ForegroundColor $color
            }
        }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Expired:  $(($results | Where-Object {$_.Status -eq 'EXPIRED'}).Count)"
Write-Host "Critical (<$CriticalDays days): $(($results | Where-Object {$_.Status -eq 'CRITICAL'}).Count)"
Write-Host "Warning  (<$WarnDays days): $(($results | Where-Object {$_.Status -eq 'WARNING'}).Count)"

$results | Sort-Object DaysLeft | Export-Csv -Path $OutputPath -NoTypeInformation
Write-Host "`nExported: $OutputPath" -ForegroundColor Green
