# Chapter 8: Cloud Identity — Entra ID Scripts

PowerShell and Microsoft Graph scripts for Entra ID operations: hybrid identity health, Tier 0 sync protection, application security, B2B guest governance, Managed Identity audit, and Graph API patterns.

## Prerequisites
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes "Directory.Read.All","Application.Read.All","AuditLog.Read.All",
                         "IdentityRiskEvent.Read.All","Policy.Read.All","User.ReadWrite.All"
```

## Scripts

### Script 8-1: Entra Connect Health Audit
**File:** `Get-EntraConnectHealth.ps1`  
**Purpose:** Audit Entra Connect sync health, last sync time, and connector status  
**Checks:** Sync cycle enabled, last successful sync age (warn >60 min), staging mode status, connector errors  
**Flags:** MSOL_ account — verifies it is not a member of admin groups

### Script 8-2: Tier 0 Sync Exclusion Verification
**File:** `Test-Tier0SyncExclusion.ps1`  
**Purpose:** Verify that Tier 0 AD accounts are excluded from Entra Connect sync  
**Method:** Compares privileged domain members against Entra ID user list; flags any matches  
**Critical:** Any Tier 0 account synced to Entra ID is a cloud-to-on-prem blast radius risk

### Script 8-3: Application Registration Security Audit
**File:** `Get-AppRegistrationSecurityAudit.ps1`  
**Purpose:** Audit all App Registrations for security hygiene issues  
**Flags:** Expiring/expired client secrets (<30 days), no owners (orphaned apps), multi-tenant apps with high-privilege permissions, Application permissions without documented justification  
**Output:** Risk-prioritized app list with specific finding per app

### Script 8-4: B2B Guest Invitation and Access Assignment
**File:** `New-B2BGuestInvitation.ps1`  
**Purpose:** Automate B2B guest invitation with controlled access assignment  
**Flow:** Invite → assign to specific group (not All Users) → set expiry via extension attribute → notify sponsor  
**Parameters:** GuestEmail, GuestCompany, AccessGroupId, DurationDays, SponsorUPN

### Script 8-5: Stale B2B Guest Audit
**File:** `Get-StaleGuestAudit.ps1`  
**Purpose:** Find B2B guests with no recent activity or unredeemed invitations  
**Flags:** Last sign-in > 90 days, ExternalUserState = PendingAcceptance (unredeemed), guests with no group assignments (floating access)  
**Output:** Stale guest list with sponsor information, recommended action (disable or remove)

### Script 8-6: Managed Identity Assignment Audit
**File:** `Get-ManagedIdentityAudit.ps1`  
**Purpose:** Audit all Managed Identities and their Azure role assignments  
**Flags:** Owner or Contributor role assignments (over-privileged), system-assigned identities on deleted resources, user-assigned identities with no assignments (orphaned)  
**Output:** Per-MI: type, resource, role assignments, risk rating

### Script 8-7: Service Principal Credential Audit
**File:** `Get-ServicePrincipalCredentialAudit.ps1`  
**Purpose:** Audit all service principals for credential hygiene  
**Flags:** Expiring secrets (<30 days), expired secrets, no certificate (client secret only), no owners, multi-tenant apps  
**Output:** Risk-sorted list, expiry timeline chart data

### Script 8-8: Graph API Identity Operations Library
**File:** `Invoke-GraphIdentityOperations.ps1`  
**Purpose:** Reusable functions for common Graph API identity operations  
**Functions:** `New-EntraUser`, `Disable-UsersInBatch`, `Get-RiskySignIns`, `Get-CAPolicyGapReport`, `Revoke-UserSessions`  
**Pattern:** Bearer token management, retry with exponential backoff on HTTP 429

### Script 8-9: Graph Delta Query for Incremental Change Tracking
**File:** `Get-GraphDeltaChanges.ps1`  
**Purpose:** Track incremental user/group changes using Graph delta queries  
**Stores:** Delta link between runs (JSON file); next run fetches only changes since last delta  
**Use case:** IGA integration, change audit, replication monitoring

### Script 8-10: AD FS to PHS Migration (Staged Rollout)
**File:** `Invoke-ADFSToPHSMigration.ps1`  
**Purpose:** Automate Staged Rollout configuration for gradual AD FS → PHS cutover  
**Phases:** Enable Staged Rollout feature → add pilot group → monitor → expand → domain cutover  
**Rollback:** Built-in function to remove group from Staged Rollout (instant fallback to AD FS)

## GitHub Actions YAML (Workload Identity Federation)
```yaml
# .github/workflows/deploy-to-azure.yml
name: Deploy to Azure (keyless)
on: [push]
permissions:
  id-token: write   # Required for OIDC token request
  contents: read
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          # No client secret — Workload Identity Federation handles auth
      - run: az account show
```

## Related Chapter Content
- PHS vs PTA vs Federation: §8.2
- App Registration vs Enterprise App: §8.3
- Tier 0 sync exclusion: §8.2
- Workload Identity Federation: §8.5
- Graph API patterns (delta, batch, throttling): §8.6
