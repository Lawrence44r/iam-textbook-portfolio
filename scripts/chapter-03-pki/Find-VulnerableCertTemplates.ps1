<#
.SYNOPSIS
    Script 3-3: Vulnerable Certificate Template Detection (ESC1/ESC2/ESC3)
.DESCRIPTION
    Enumerates all AD CS certificate templates and flags dangerous configurations.
    ESC1: Enrollee supplies SAN + Client Auth EKU + wide enrollment = impersonate any user
    ESC2: Any Purpose EKU = can be used for any purpose including client auth
    ESC3: Certificate Request Agent EKU = enroll on behalf of another user
.NOTES
    Requires: ActiveDirectory module, AD read access
    Reference: https://posts.specterops.io/certified-pre-owned-d95910965cd2
    Chapter 3 §3.6 — ESC Attack Categories
#>
[CmdletBinding()]
param(
    [string]$ForestDN = (Get-ADForest).PartitionsContainer -replace 'CN=Partitions,',''
)

Import-Module ActiveDirectory -ErrorAction Stop

# OID constants
$OID_CLIENT_AUTH        = '1.3.6.1.5.5.7.3.2'
$OID_ANY_PURPOSE        = '2.5.29.37.0'
$OID_CERT_REQUEST_AGENT = '1.3.6.1.4.1.311.20.2.1'

# CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT = 0x00000001
$CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT = 0x1

function Get-TemplateEKUs {
    param($Template)
    $ekuAttr = $Template.'msPKI-Certificate-Application-Policy'
    if (-not $ekuAttr) { $ekuAttr = $Template.'pKIExtendedKeyUsage' }
    return $ekuAttr
}

Write-Host "`n=== Vulnerable Certificate Template Scan ===" -ForegroundColor Cyan
Write-Host "Forest: $ForestDN | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$templatePath = "CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,$ForestDN"
$templates = Get-ADObject -SearchBase $templatePath -Filter { objectClass -eq 'pKICertificateTemplate' } `
    -Properties * -ErrorAction Stop

Write-Host "Templates found: $($templates.Count)`n"

$results = @()

foreach ($tmpl in $templates) {
    $msPKIFlags    = [int]($tmpl.'msPKI-Certificate-Name-Flag' -bor 0)
    $ekus          = Get-TemplateEKUs -Template $tmpl
    $enrolleesSAN  = ($msPKIFlags -band $CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT) -ne 0
    $hasClientAuth = $ekus -contains $OID_CLIENT_AUTH
    $hasAnyPurpose = $ekus -contains $OID_ANY_PURPOSE
    $hasReqAgent   = $ekus -contains $OID_CERT_REQUEST_AGENT

    # ESC1: enrollee supplies SAN + Client Auth + wide enrollment
    $isESC1 = $enrolleesSAN -and $hasClientAuth

    # ESC2: Any Purpose EKU (effectively grants Client Auth)
    $isESC2 = $hasAnyPurpose

    # ESC3: Certificate Request Agent EKU
    $isESC3 = $hasReqAgent

    if ($isESC1 -or $isESC2 -or $isESC3) {
        $findings = @()
        if ($isESC1) { $findings += 'ESC1' }
        if ($isESC2) { $findings += 'ESC2' }
        if ($isESC3) { $findings += 'ESC3' }

        $severity = if ($isESC1 -or $isESC2) { 'CRITICAL' } else { 'HIGH' }
        $color    = if ($severity -eq 'CRITICAL') { 'Red' } else { 'Yellow' }

        Write-Host "[$severity] $($tmpl.Name)" -ForegroundColor $color
        Write-Host "  Finding(s): $($findings -join ', ')"
        Write-Host "  EnrolleeSAN: $enrolleesSAN | ClientAuth: $hasClientAuth | AnyPurpose: $hasAnyPurpose | ReqAgent: $hasReqAgent"

        $results += [PSCustomObject]@{
            TemplateName    = $tmpl.Name
            DisplayName     = $tmpl.'displayName'
            Severity        = $severity
            ESC1            = $isESC1
            ESC2            = $isESC2
            ESC3            = $isESC3
            EnrolleeSAN     = $enrolleesSAN
            HasClientAuth   = $hasClientAuth
            HasAnyPurpose   = $hasAnyPurpose
            HasRequestAgent = $hasReqAgent
            Remediation     = switch ($true) {
                $isESC1 { "Disable CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT on '$($tmpl.Name)' or restrict enrollment permissions" }
                $isESC2 { "Replace Any Purpose EKU with specific EKUs on '$($tmpl.Name)'" }
                $isESC3 { "Restrict enrollment on '$($tmpl.Name)' to authorized CA Enrollment Agents only" }
            }
        }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Templates scanned: $($templates.Count)"
Write-Host "Vulnerable:        $($results.Count)"
Write-Host "  ESC1 (Critical): $(($results | Where-Object { $_.ESC1 }).Count)"
Write-Host "  ESC2 (Critical): $(($results | Where-Object { $_.ESC2 }).Count)"
Write-Host "  ESC3 (High):     $(($results | Where-Object { $_.ESC3 }).Count)"

if ($results.Count -gt 0) {
    $results | Export-Csv -Path ".\VulnerableTemplates_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
    Write-Host "`nExported: VulnerableTemplates_$(Get-Date -Format 'yyyyMMdd').csv" -ForegroundColor Green
    Write-Host "`nRemediation priority: ESC1 > ESC2 > ESC3" -ForegroundColor Yellow
    Write-Host "Use Certify or PSPKIAudit to enumerate which accounts can enroll in each template." -ForegroundColor Gray
} else {
    Write-Host "`n[CLEAN] No ESC1/ESC2/ESC3 vulnerable templates found" -ForegroundColor Green
}
