# Chapter 3: PKI and Certificate Services Scripts

PowerShell scripts for auditing ADCS infrastructure, detecting vulnerable certificate templates, monitoring certificate lifecycle, and validating revocation configuration.

## Prerequisites
```powershell
# ADCS management module (on CA server or with Remote Server Administration Tools)
Import-Module ADCSAdministration
Import-Module ADCSDeployment

# For non-CA servers: use certutil.exe (built-in) + PowerShell wrappers
```

## Scripts

### Script 3-1: CA Infrastructure Audit
**File:** `Get-CAInfrastructureAudit.ps1`  
**Purpose:** Enumerate all CAs in the enterprise, check certificate expiry, validate web enrollment exposure  
**Key checks:** CA certificate expiry (warn 180 days, critical 90 days), HTTP vs HTTPS certsrv (ESC8 surface), CRL publication freshness  
**Output:** CA inventory with health status, expiry timeline

### Script 3-2: Certificate Revocation Status Check
**File:** `Test-CertificateRevocation.ps1`  
**Purpose:** Check revocation status for all certificates on a target server  
**Methods:** CRL download + OCSP query per certificate  
**Output:** Per-cert revocation status, CRL freshness, OCSP response time

### Script 3-3: Vulnerable Template Detection (ESC1/ESC2/ESC3)
**File:** `Find-VulnerableCertTemplates.ps1`  
**Purpose:** Enumerate all certificate templates and flag dangerous configurations  
**Detects:**
- ESC1: enrollee_supplies_subject + Client Auth EKU + wide enrollment
- ESC2: Any Purpose EKU (catch-all dangerous)
- ESC3: Certificate Request Agent EKU enabling enrollment on behalf of others
**Output:** Per-template risk rating, specific misconfiguration, remediation steps

### Script 3-4: Certificate Autoenrollment Configuration
**File:** `Set-AutoenrollmentPolicy.ps1`  
**Purpose:** Configure and verify GPO-based autoenrollment for domain-joined computers and users  
**Validates:** GPO settings, autoenrollment event logs (Event 6, 13, 16), enrollment status

### Script 3-5: ESC8 Vulnerability Check
**File:** `Test-ESC8Vulnerability.ps1`  
**Purpose:** Detect ADCS web enrollment (certsrv) accessible over HTTP — prerequisite for NTLM relay to ADCS  
**Test:** Connects to certsrv over HTTP; checks for NTLM authentication header  
**Remediation:** Disable HTTP, enforce HTTPS + EPA (Extended Protection for Authentication)

### Script 3-6: Smart Card and WHfB Enrollment Audit
**File:** `Get-SmartCardEnrollmentAudit.ps1`  
**Purpose:** Audit smart card and Windows Hello for Business enrollment status across the domain  
**Checks:** msDS-KeyCredentialLink population (WHfB), PIV certificate enrollment, NTAuthCertificates store contents  
**Output:** Per-user enrollment status, coverage percentage by department/OU

### Script 3-7: Certificate Expiry Monitoring
**File:** `Get-CertificateExpiryReport.ps1`  
**Purpose:** Monitor all certificates issued by enterprise CAs for approaching expiry  
**Thresholds:** Warn at 60 days, critical at 30 days  
**Output:** Expiry report sorted by days remaining, CSV export for ticketing integration

### Script 3-8: Force Autoenrollment and Verify
**File:** `Invoke-CertificateAutoenrollment.ps1`  
**Purpose:** Force certificate autoenrollment on a target machine and verify the correct templates were enrolled  
**Use case:** Post-template-change verification, new machine onboarding validation

### Script 3-9: OpenSSL Reference Commands
**File:** `openssl-reference.md`  
**Purpose:** 15-command reference for OpenSSL operations (key generation, CSR, chain validation, OCSP testing, PKCS12)  
**Note:** Cross-platform (Linux/macOS/Windows with OpenSSL installed)

## Permissions Required
- Read access to `CN=Public Key Services,CN=Services,CN=Configuration,DC=...` in AD (default for Domain Users)
- CA Manager or CA Administrator role for `ADCSAdministration` module commands
- Local Admin on CA server for some `certutil` operations

## certutil Quick Reference
```
certutil -ping                    # Test CA connectivity
certutil -verify cert.cer         # Verify certificate chain
certutil -URL cert.cer            # Check CDP and AIA URLs
certutil -crl                     # Force CRL republish (on CA)
certutil -backup C:\backup\       # Backup CA database (on CA)
certutil -template                # List all templates visible to this machine
```

## Related Chapter Content
- ESC attack categories: §3.6
- PKI hierarchy design: §3.3
- OCSP vs CRL: §3.4
- WHfB and Shadow Credentials: §3.8
