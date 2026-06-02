# Chapter 10: Defender XDR and Zero Trust Implementation Scripts

PowerShell scripts and Sentinel KQL rules for Microsoft Defender XDR operations, Identity Protection risk management, CAE deployment, Conditional Access tiered audit, and Zero Trust baseline measurement.

## Prerequisites
```powershell
Connect-MgGraph -Scopes "IdentityRiskEvent.Read.All","IdentityRiskyUser.ReadWrite.All",
                         "Policy.Read.All","AuditLog.Read.All","Directory.Read.All",
                         "SecurityEvents.Read.All","User.ReadWrite.All"
```

## Scripts

### Script 10-1: Identity Protection Risk Audit
**File:** `Get-IdentityProtectionRiskAudit.ps1`  
**Purpose:** Query all risky users and risky sign-ins; generate prioritized remediation report  
**Prioritizes:** High-risk users who are also admins (highest priority), then high-risk standard users  
**Actions:** `RequirePasswordChange`, `DismissRisk`, `BlockUser` (with -WhatIf support)  
**Notifications:** SOC email on BlockUser action

### Script 10-2: CAE Coverage Analysis
**File:** `Test-CAECoverage.ps1`  
**Purpose:** Measure what percentage of sign-ins use CAE-capable clients vs. legacy auth  
**Output:** Client auth type breakdown, users still on legacy auth, CAE revocation readiness guidance  
**Test:** Issues test revocation to measure actual token invalidation latency

### Script 10-3: Conditional Access Tiered Policy Audit
**File:** `Get-CATieredAudit.ps1`  
**Purpose:** Evaluate CA policies against the 5-tier model (Baseline/Identity/Device/Privileged/App)  
**Checks:** Per-tier pass/fail, break-glass exclusion inventory, report-only policy count  
**Output:** Priority action list, full CSV export of all policies

### Script 10-4: Defender XDR Incident Summary
**File:** `Get-DefenderXDRSummary.ps1`  
**Purpose:** Query Defender XDR incidents via Security Graph API; produce SOC summary  
**Metrics:** Incident count by severity, MTTR for resolved incidents, identity-related incident %  
**Non-compliant device inventory:** Pulls Intune-enrolled devices failing compliance

### Script 10-5: Zero Trust Baseline Assessment
**File:** `Measure-ZeroTrustBaseline.ps1`  
**Purpose:** Measure current ZT maturity across all pillars; export JSON for trend tracking  
**Measures:** MFA registration %, phishing-resistant auth %, CA policy count, legacy auth volume, risky user count, device compliance %, Global Admin count  
**Use:** Run monthly; compare JSON exports to show maturity progress  
**Output:** Console dashboard + `ZT_Baseline_YYYYMMDD.json`

### Script 10-6: Defender for Identity Alert Triage
**File:** `Get-MDIAlertTriage.ps1`  
**Purpose:** Query Defender for Identity alerts and triage by severity and entity  
**Prioritizes:** Alerts involving Tier 0 entities (DCs, CA servers, Entra Connect)  
**Correlates:** MDI alert + Entra ID sign-in within 30-min window (lateral movement indicator)

## Sentinel KQL Analytics Rules

**File:** `sentinel-kql-rules/`

```
sentinel-kql-rules/
├── impossible-travel.kql             # Sign-in from 2 countries within 1 hour
├── msol-anomaly-detection.kql        # Entra Connect sync account unusual operations
├── global-admin-assignment.kql       # Any Global/Security Admin role assignment
├── service-principal-cred-add.kql    # Secret or certificate added to app registration
├── mass-user-modification.kql        # >20 user modifications in 15 minutes
├── kerberoasting-detection.kql       # Bulk Event 4769 RC4 type 0x17 requests
└── dcsync-detection.kql              # DS-Replication-Get-Changes from unexpected source
```

### Deploying KQL Rules to Sentinel
```powershell
# Deploy via Azure PowerShell
$workspace = "your-sentinel-workspace"
$resourceGroup = "your-rg"

Get-ChildItem ".\sentinel-kql-rules\*.kql" | ForEach-Object {
    $query = Get-Content $_.FullName -Raw
    $ruleName = $_.BaseName
    
    # Deploy as Scheduled Analytics Rule via REST API or az cli
    az monitor log-analytics workspace saved-search create `
        --resource-group $resourceGroup `
        --workspace-name $workspace `
        --name $ruleName `
        --display-name $ruleName `
        --category "IAM Security" `
        --saved-query $query
}
```

## SOAR Playbook Reference

**File:** `soar-playbooks/high-risk-user-remediation.json`  
Logic App definition for automated response to high-risk Identity Protection alerts:
1. Trigger: Sentinel incident (entity type = Account, severity = High)
2. Action: Revoke all user refresh tokens
3. Action: Notify SOC via Teams webhook
4. Action: Create Sentinel comment with remediation details

## ZT Implementation Roadmap

**File:** `zt-roadmap-template.xlsx` (export from Chapter 10 §10.8)  
18-month phased Zero Trust implementation schedule:
- Phase 1 (M1-3): Identity Foundation
- Phase 2 (M3-6): Device Compliance
- Phase 3 (M6-9): Application Controls
- Phase 4 (M9-12): Network and Monitoring

## Related Chapter Content
- Identity Protection risk detections: §10.2
- CAE architecture: §10.3
- CA tiered model: §10.4
- Defender for Identity: §10.5
- MSEM and attack paths: §10.6
- Sentinel KQL rules: §10.7
- 18-month ZT implementation runbook: §10.8
