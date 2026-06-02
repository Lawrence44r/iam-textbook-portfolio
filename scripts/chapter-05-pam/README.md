# Chapter 5: Privileged Access Management Scripts

PowerShell scripts for PAM program operations: CyberArk auditing, Azure PIM governance, JIT access, PowerShell logging, LAPS, PAW compliance, and break-glass monitoring.

## Scripts

### Script 5-1: CyberArk REST API — Account and Safe Audit
**File:** `Get-CyberArkAudit.ps1`  
**Purpose:** Authenticate to CyberArk PVWA REST API and audit safe/account inventory  
**Covers:** Safe enumeration, accounts with rotation failures, accounts not rotated in >90 days, accounts without PSM association  
**Requires:** PVWA URL, CyberArk user with Audit Users permission

### Script 5-2: Azure PIM Role Assignment Audit
**File:** `Get-PIMAudit.ps1`  
**Purpose:** Audit PIM eligible vs. active role assignments, activation patterns, and anti-patterns  
**Flags:** Permanent active assignments (not eligible), activations without MFA, Global Admin eligible count > 5  
**Requires:** `RoleManagement.Read.All` Graph permission

### Script 5-3: JIT Group Membership with Auto-Expiry
**File:** `New-JITGroupMembership.ps1`  
**Purpose:** Grant time-bounded AD group membership with automatic scheduled revocation  
**Parameters:** User, Group, DurationHours (1-24), Justification, TicketNumber  
**Mechanism:** Adds group membership + creates scheduled task to remove at expiry

### Script 5-4: PowerShell Enhanced Logging Configuration
**File:** `Set-PowerShellLogging.ps1`  
**Purpose:** Configure Script Block Logging (Event 4104), Module Logging (4103), and Transcription via registry/GPO  
**Output:** Current logging status, recommended GPO settings, Event Log size recommendations

### Script 5-5: Suspicious PowerShell Command Detection
**File:** `Find-SuspiciousPSCommands.ps1`  
**Purpose:** Analyze Script Block Logging (Event 4104) for known attack tool signatures  
**Detects:** mimikatz, Invoke-Mimikatz, PowerSploit functions, AMSI bypass patterns, encoded command obfuscation, credential access patterns  
**Output:** Timeline of suspicious events with user, machine, and command hash

### Script 5-6: Windows LAPS Deployment Audit
**File:** `Get-LAPSAudit.ps1`  
**Purpose:** Audit LAPS coverage, password age, and retrieval activity  
**Covers:** Computers with/without LAPS enrolled, passwords older than policy threshold, retrieval event log (Event 4662)  
**Distinguishes:** Legacy LAPS (ms-Mcs-AdmPwd) vs. Windows LAPS (msLAPS-Password)

### Script 5-7: LAPS ACL Configuration
**File:** `Set-LAPSAttributeACLs.ps1`  
**Purpose:** Configure AD ACLs for LAPS attribute access (read delegation to helpdesk groups)  
**Grants:** Read on `msLAPS-Password` to specified security group per OU scope  
**Validates:** No broad delegation (no Domain Users read access)

### Script 5-8: PAW Compliance Audit
**File:** `Test-PAWCompliance.ps1`  
**Purpose:** Detect administrative activity performed from non-PAW workstations  
**Method:** Correlate admin logon events (Event 4624 Type 10/3) with source workstation against PAW computer list  
**Flags:** Admin accounts logging on from workstations not in PAW OU  
**Output:** Per-admin: % of admin sessions from PAW vs. non-PAW

### Script 5-9: Break-Glass Account Monitoring
**File:** `Watch-BreakGlassAccounts.ps1`  
**Purpose:** Audit break-glass account configuration and alert on any use  
**Validates:** Cloud-only (not synced), FIDO2-only MFA, excluded from all CA policies, no PIM assignments  
**Use monitoring:** Parses Entra ID sign-in logs for any break-glass sign-in (should be 0 in normal operations)

## HashiCorp Vault Quick Reference
```bash
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/prod-db \
  plugin_name=postgresql-database-plugin \
  connection_url="postgresql://{{username}}:{{password}}@db.company.com:5432/prod" \
  allowed_roles="app-role" \
  username="vault-root" \
  password="<root-password>"

# Create role (dynamic credentials)
vault write database/roles/app-role \
  db_name=prod-db \
  creation_statements="CREATE ROLE '{{name}}' WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';" \
  default_ttl="1h" \
  max_ttl="24h"

# Application requests credential
vault read database/creds/app-role
# Returns: username=v-app-role-xyz, password=<random>, lease_duration=1h
```

## Related Chapter Content
- CyberArk architecture: §5.3
- JIT access models: §5.4
- PAW security profile: §5.6
- Tiered administration model: §5.6
- Break-glass design: §5.7
