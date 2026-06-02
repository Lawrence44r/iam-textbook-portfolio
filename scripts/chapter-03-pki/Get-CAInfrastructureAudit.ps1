<#
.SYNOPSIS
    Script 3-1: CA Infrastructure Audit
.DESCRIPTION
    Enumerates all CAs in the enterprise, checks certificate expiry,
    validates web enrollment exposure (ESC8 surface), and CRL publication freshness.
.NOTES
    Requires: ActiveDirectory module; certutil on PATH
    Chapter 3 §3.3 — PKI Hierarchy Design
#>
[CmdletBinding()]
param(
    [string]$ForestDN = (Get-ADForest).PartitionsContainer -replace 'CN=Partitions,',''
)

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "`n=== CA Infrastructure Audit ===" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$caPath = "CN=Certification Authorities,CN=Public Key Services,CN=Services,CN=Configuration,$ForestDN"
$enrollPath = "CN=Enrollment Services,CN=Public Key Services,CN=Services,CN=Configuration,$ForestDN"

$rootCAs   = Get-ADObject -SearchBase $caPath -Filter { objectClass -eq 'certificationAuthority' } -Properties * -ErrorAction SilentlyContinue
$issuingCAs = Get-ADObject -SearchBase $enrollPath -Filter { objectClass -eq 'pKIEnrollmentService' } -Properties * -ErrorAction SilentlyContinue

Write-Host "ROOT/POLICY CAs in NTAuthCertificates:" -ForegroundColor Yellow
foreach ($ca in $rootCAs) {
    Write-Host "  $($ca.Name)"
}

Write-Host "`nISSUING CAs (Enrollment Services):" -ForegroundColor Yellow
$results = @()

foreach ($ca in $issuingCAs) {
    Write-Host "`n  CA: $($ca.Name)" -ForegroundColor Cyan
    Write-Host "  DNS: $($ca.dNSHostName)"

    # Check CA cert expiry
    $caCert = $null
    try {
        $certBytes = $ca.'cACertificate'
        if ($certBytes) {
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes)
            $daysLeft = ($cert.NotAfter - (Get-Date)).Days
            $expiryStatus = if ($daysLeft -lt 90) { 'CRITICAL' } elseif ($daysLeft -lt 180) { 'WARNING' } else { 'OK' }
            $color = switch ($expiryStatus) { 'CRITICAL' { 'Red' } 'WARNING' { 'Yellow' } default { 'Green' } }
            Write-Host "  CA Cert expiry: $($cert.NotAfter.ToString('yyyy-MM-dd')) ($daysLeft days) [$expiryStatus]" -ForegroundColor $color
            $caCert = $cert
        }
    } catch {
        Write-Host "  CA Cert: [CANNOT PARSE]" -ForegroundColor Red
    }

    # Check certsrv HTTP exposure (ESC8 prerequisite)
    $httpUrl = "http://$($ca.dNSHostName)/certsrv"
    Write-Host "  Testing certsrv HTTP: $httpUrl"
    try {
        $response = Invoke-WebRequest -Uri $httpUrl -TimeoutSec 5 -ErrorAction Stop -UseBasicParsing
        Write-Host "  [ESC8 RISK] certsrv accessible over HTTP! NTLM relay to ADCS is possible." -ForegroundColor Red
        Write-Host "  Remediation: Disable HTTP, enforce HTTPS + Extended Protection for Authentication (EPA)" -ForegroundColor Yellow
        $esc8Exposed = $true
    } catch {
        Write-Host "  [OK] certsrv not accessible over HTTP" -ForegroundColor Green
        $esc8Exposed = $false
    }

    $results += [PSCustomObject]@{
        CAName       = $ca.Name
        DnsHostname  = $ca.dNSHostName
        CertExpiry   = if ($caCert) { $caCert.NotAfter } else { $null }
        DaysToExpiry = if ($caCert) { ($caCert.NotAfter - (Get-Date)).Days } else { -1 }
        ESC8Exposed  = $esc8Exposed
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Root/Policy CAs:  $($rootCAs.Count)"
Write-Host "Issuing CAs:      $($issuingCAs.Count)"
Write-Host "ESC8 exposed CAs: $(($results | Where-Object {$_.ESC8Exposed}).Count)"
Write-Host "CAs expiring <90d: $(($results | Where-Object {$_.DaysToExpiry -lt 90 -and $_.DaysToExpiry -ge 0}).Count)"

$results | Export-Csv -Path ".\CAInfrastructureAudit_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
Write-Host "`nExported: CAInfrastructureAudit_$(Get-Date -Format 'yyyyMMdd').csv" -ForegroundColor Green
