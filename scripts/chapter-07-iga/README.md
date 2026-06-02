# Chapter 7: Identity Governance and Administration Scripts

PowerShell scripts for IGA lifecycle automation: Leaver processing, orphaned account detection, SCIM endpoint testing, role mining, SoD violation detection, access certification, and SOX audit evidence generation.

## Scripts

### Script 7-1: Automated Leaver Processing
**File:** `Invoke-LeaverProcessing.ps1`  
**Purpose:** Immediate access revocation for terminated employees (4-hour SLA target)  
**Actions:** Disable AD account, move to Terminated OU, remove all group memberships, revoke Entra ID sessions, notify manager, log all actions  
**Trigger:** HR webhook or scheduled task comparing AD accounts to HR terminated list  
**Output:** Audit log entry with WHO/WHAT/WHEN/WHY for each action

### Script 7-2: Orphaned Account Detection
**File:** `Find-OrphanedAccounts.ps1`  
**Purpose:** Find active AD/Entra accounts with no corresponding active HR record  
**Method:** Joins AD account list with HR active employee extract (CSV or API)  
**Flags:** Accounts in AD not in HR active, accounts with no logon in 90+ days, service accounts with no documented owner  
**Output:** Orphan list with last logon, group memberships, recommended action

### Script 7-3: SCIM Endpoint Validation
**File:** `Test-SCIMEndpoint.ps1`  
**Purpose:** Validate a SCIM 2.0 endpoint by running a full Create/Read/Patch/Delete lifecycle test  
**Tests:** POST (create), GET (read by ID), GET (filter by externalId), PATCH (update), DELETE  
**Validates:** HTTP status codes, response schema (SCIM schema compliance), externalId round-trip  
**Use case:** Validating new application SCIM integration before go-live

### Script 7-4: Role Mining — Access Pattern Analysis
**File:** `Invoke-RoleMining.ps1`  
**Purpose:** Analyze current access patterns to identify candidate RBAC roles  
**Method:** Bottom-up mining — clusters users with similar entitlement sets  
**Output:** Candidate roles with: member list, entitlement set, coverage %, suggested role name  
**Parameters:** MinCoverage (minimum % of users in cluster to propose as role), MaxEntitlements

### Script 7-5: SoD Violation Detection
**File:** `Find-SoDViolations.ps1`  
**Purpose:** Detect Segregation of Duties conflicts across AD group memberships  
**Input:** SoD matrix (CSV: Role1, Role2, Severity, Description), AD group membership  
**Output:** Per-user violations with: conflicting groups, severity, days violation has existed  
**Handles:** Cross-application SoD (AD groups representing entitlements in different systems)

### Script 7-6: Access Certification Campaign Data
**File:** `New-AccessCertificationCampaign.ps1`  
**Purpose:** Generate manager-ready access certification data with context enrichment  
**Enriches each item with:** Last use date, usage frequency (90 days), peer group %, SoD risk flag, entitlement acquisition date and method  
**Output:** JSON suitable for import to SailPoint/ServiceNow/SharePoint campaign workflow

### Script 7-7: SOX ITGC Access Control Audit Report
**File:** `Get-SOXITGCAuditReport.ps1`  
**Purpose:** Generate 5-section SOX ITGC evidence package for access control audit  
**Sections:**
1. User access inventory (all enabled accounts with privileged access)
2. Access review evidence (certification campaign completion rates)
3. Provisioning/deprovisioning timeliness (vs. SLA)
4. Terminated employee access (any access surviving >4 hours post-termination)
5. Privileged access changes (all admin group changes in period)  
**Output:** Formatted report + supporting CSV evidence files

## SoD Matrix Format
```csv
Role1,Role2,Severity,Description,CompensatingControl
AP-Create-Vendor,AP-Approve-Payment,CRITICAL,Vendor creation + payment approval = financial fraud,None - hard block
AP-Create-Vendor,AP-Modify-Vendor,HIGH,Can create and then modify own vendors,Enhanced monitoring + quarterly review
Prescribe-Drug,Dispense-Drug,CRITICAL,Prescriber + dispenser = medication diversion risk,None - hard block
```

## Related Chapter Content
- JML lifecycle and SLAs: §7.2
- SCIM 2.0 protocol: §7.3
- RBAC vs ABAC: §7.5
- SoD matrix design: §7.6
- Access certification best practices: §7.7
- SOX/HIPAA/PCI compliance mapping: §7.1
