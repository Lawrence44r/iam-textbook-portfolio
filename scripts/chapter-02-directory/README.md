# Chapter 2: Directory Services Scripts

PowerShell scripts for auditing Active Directory architecture, attack surface, and operational health. All scripts require the `ActiveDirectory` PowerShell module (RSAT) and appropriate read permissions.

## Prerequisites
```powershell
# Install RSAT (Windows 10/11)
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Or import if already installed
Import-Module ActiveDirectory
```

## Scripts

### Script 2-1: FSMO Role Holder Audit
**File:** `Get-FSMORoleHolders.ps1`  
**Purpose:** Identify all FSMO role holders across forest and all domains  
**Key output:** Forest roles (Schema Master, Domain Naming Master), per-domain roles (PDC Emulator, RID Master, Infrastructure Master)  
**Watch for:** Infrastructure Master co-located with Global Catalog server in multi-domain forests

### Script 2-2: Dangerous userAccountControl Flag Audit
**File:** `Find-DangerousAccountFlags.ps1`  
**Purpose:** Find accounts with dangerous userAccountControl bitmask flags  
**Flags detected:** TRUSTED_FOR_DELEGATION (unconstrained delegation), PASSWD_NOTREQD, DONT_EXPIRE_PASSWORD, TRUSTED_TO_AUTH_FOR_DELEGATION  
**Output:** CSV with account name, flag, last logon, group memberships

### Script 2-3: Kerberos Attack Surface Audit
**File:** `Get-KerberosAttackSurface.ps1`  
**Purpose:** Enumerate all accounts vulnerable to Kerberoasting, AS-REP Roasting, and delegation abuse  
**Detects:** SPNs on user accounts (Kerberoastable), accounts with pre-auth disabled (AS-REP Roastable), unconstrained delegation (computer + user), krbtgt password age  
**Output:** Per-risk-category lists with remediation guidance

### Script 2-4: Group Nesting and Universal Group Audit
**File:** `Measure-GroupNestingDepth.ps1`  
**Purpose:** Find deeply nested groups contributing to PAC token bloat  
**Output:** Groups with nesting depth > 3, Universal groups with member count, estimated SID contribution

### Script 2-5: Stale Group Detection
**File:** `Find-EmptyAndStaleGroups.ps1`  
**Purpose:** Find empty groups and groups with no recent membership changes (stale cleanup candidates)  
**Output:** Groups with 0 members, groups unchanged for >365 days, recommended cleanup list

### Script 2-6: GPO Coverage and Inheritance Audit
**File:** `Get-GPOCoverageAudit.ps1`  
**Purpose:** Find orphaned/unlinked GPOs, OUs with Block Inheritance, GPO coverage gaps  
**Output:** Unlinked GPOs (waste/risk), OUs blocking inheritance (policy gaps), RSoP summary

### Script 2-7: NTLM Usage and Restriction Audit
**File:** `Get-NTLMUsageAudit.ps1`  
**Purpose:** Measure NTLM usage in the environment and verify restriction settings  
**Checks:** LmCompatibilityLevel registry value, Event 8004 (NTLM authentication) volume, applications generating NTLM  
**Target:** LmCompatibilityLevel = 5 (NTLMv2 only, refuse LM/NTLMv1)

### Script 2-8: Trust and SID Filtering Audit
**File:** `Get-TrustSIDFilteringAudit.ps1`  
**Purpose:** Enumerate all AD trusts and verify SID filtering (quarantine) is enabled  
**Risk:** Trusts without SID filtering allow sIDHistory-based privilege escalation  
**Output:** Per-trust: type, direction, SID filtering status, transitive status, forest topology

### Script 2-9: AD Health Dashboard
**File:** `Get-ADHealthDashboard.ps1`  
**Purpose:** Complete AD operational health check in a single script  
**Covers:** Replication status, account statistics (enabled/disabled/stale), privileged group membership, FSMO confirmation, krbtgt age, DC OS versions  
**Output:** Console dashboard + JSON export for trend tracking

## Permissions Required
- `Domain Users` is sufficient for most read operations
- `Domain Admins` or explicit delegation required for replication status queries
- For production use: create a dedicated read-only audit service account

## Related Chapter Content
- Kerberos attack taxonomy: §2.4
- FSMO roles and traps: §2.2
- Trust architecture: §2.6
- GPO processing order (LSDOU): §2.3
