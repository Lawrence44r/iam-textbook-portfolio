# Chapter 6: Zero Trust Architecture Scripts

PowerShell scripts for Conditional Access gap analysis, CAE verification, Named Location management, NSG micro-segmentation audit, and Zero Trust maturity assessment.

## Prerequisites
```powershell
Connect-MgGraph -Scopes "Policy.Read.All","Policy.ReadWrite.ConditionalAccess",
                         "Directory.Read.All","NetworkAccessPolicy.Read.All"
```

## Scripts

### Script 6-1: Conditional Access Policy Gap Analysis
**File:** `Get-CAPolicyGapAnalysis.ps1`  
**Purpose:** Evaluate CA policy set against the tiered model; flag gaps  
**Checks:**
- Tier B (Baseline): legacy auth blocked, MFA for all users
- Tier I (Identity Protection): sign-in risk → MFA, user risk → password change
- Tier D (Device): compliant device enforcement, session controls for unmanaged
- Tier P (Privileged): admin roles require phishing-resistant MFA + PAW location
- Tier A (Application): high-sensitivity app controls
**Output:** Pass/Fail per tier, priority action list, CSV export of all policies

### Script 6-2: Named Locations and Geo-Based CA Policy
**File:** `Set-NamedLocationsAndGeoCA.ps1`  
**Purpose:** Create trusted IP Named Locations (PAW VLAN, VPN egress) and geo-blocking CA policies  
**Creates:** Named Location objects in Entra ID + associated CA policies in report-only mode  
**Parameters:** PAW IP ranges, VPN IP ranges, blocked country codes (ISO)

### Script 6-3: CAE Verification and Emergency Session Revocation
**File:** `Test-CAEAndRevocation.ps1`  
**Purpose:** Verify CAE is functioning and test emergency session revocation latency  
**Measures:** % of sign-ins using modern auth (CAE-capable) vs. legacy auth  
**Test:** Issues revocation for a test user, measures time until Exchange rejects token  
**Requires:** `User.ReadWrite.All` for revocation test (use test account only)

### Script 6-4: Entra Application Proxy Configuration
**File:** `New-AppProxyPublishing.ps1`  
**Purpose:** Publish an on-premises web application via Entra Application Proxy (agentless ZTNA)  
**Configures:** External URL, internal URL, pre-authentication (Entra ID), connector group  
**Result:** Internal app accessible externally without VPN, with Entra ID auth + CA policy enforcement

### Script 6-5: NSG Micro-Segmentation Audit
**File:** `Get-NSGMicroSegmentationAudit.ps1`  
**Purpose:** Audit Azure Network Security Group rules for Zero Trust micro-segmentation gaps  
**Flags:** Any-to-Any rules, inbound rules allowing broad port ranges (0-65535), missing deny-all defaults  
**Output:** Per-NSG risk rating, specific over-permissive rules, east-west traffic paths

### Script 6-6: Zero Trust Maturity Self-Assessment
**File:** `Measure-ZeroTrustMaturity.ps1`  
**Purpose:** Interactive 5-pillar CISA ZT Maturity Model self-assessment  
**Pillars:** Identity, Device, Network, Application, Data  
**Scoring:** Traditional (0) / Advanced (1) / Optimal (2) per control per pillar  
**Output:** Maturity radar chart data (JSON), priority roadmap, executive summary

## CA Policy Templates (JSON)

The `templates/` subfolder contains JSON templates for common CA policies deployable via Microsoft Graph:

```
templates/
├── B-01-block-legacy-auth.json
├── B-02-require-mfa-all-users.json
├── I-01-signin-risk-medium-mfa.json
├── I-02-signin-risk-high-block.json
├── I-03-user-risk-high-password-change.json
├── D-01-require-compliant-device.json
├── D-02-unmanaged-device-session-controls.json
├── P-01-admin-roles-paw-phishing-resistant.json
└── P-02-break-glass-exclusion-template.json
```

Deploy with:
```powershell
$policy = Get-Content ".\templates\B-01-block-legacy-auth.json" | ConvertFrom-Json
New-MgIdentityConditionalAccessPolicy -BodyParameter $policy
```

## Related Chapter Content
- NIST SP 800-207 tenets: §6.1
- CISA ZT Maturity Model: §6.2
- CAE deep dive: §6.5 (see also Chapter 10 §10.3)
- ZTNA deployment models: §6.6
- Zero Trust implementation sequence: §6.7
