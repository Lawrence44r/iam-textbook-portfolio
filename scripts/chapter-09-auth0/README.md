# Chapter 9: Auth0 / CIAM Scripts

Node.js and PowerShell scripts for Auth0 tenant management, organization provisioning, vendor access lifecycle, M2M token patterns, lazy migration, and tenant-as-code deployment.

## Prerequisites
```bash
npm install node-fetch jsonwebtoken uuid
npm install -g auth0-deploy-cli   # For tenant-as-code
```

```powershell
# Auth0 Management API token (M2M app with Management API scopes)
$env:AUTH0_DOMAIN = "yourcompany.auth0.com"
$env:AUTH0_MGMT_TOKEN = "<management-api-token>"
```

## Scripts

### Script 9-1: Organization Provisioning
**File:** `New-Auth0Organization.js`  
**Purpose:** Provision a new Auth0 Organization for a B2B SaaS customer  
**Actions:** Create org → enable connections → create default roles → send admin invitation  
**Parameters:** customerSlug, companyName, logoUrl, primaryColor, adminEmail, plan, seats  
**Use case:** Triggered by CRM webhook on new customer contract signing

### Script 9-2: Vendor Access Management
**File:** `Manage-VendorAccess.ps1`  
**Purpose:** Time-bounded vendor access provisioning with automatic expiry  
**Provisions:** B2B guest invitation → time-bounded group membership → CA scope tagging → notification to sponsor  
**Expiry:** Scheduled task checks hourly; disables account + revokes tokens + removes groups at expiry  
**Full implementation:** See Chapter 11 §11.6 for the complete Vertex Health vendor access architecture

### Script 9-3: M2M Token Cache Pattern
**File:** `Auth0TokenCache.js`  
**Purpose:** Production-ready M2M token caching class  
**Features:** In-memory cache with TTL tracking, 60-second pre-expiry refresh, thread-safe for concurrent requests  
**Why:** Auth0 charges per M2M token issuance; uncached services can generate thousands of tokens per hour

### Script 9-4: Custom Database Login Script
**File:** `custom-db-login.js`  
**Purpose:** Auth0 Custom Database connection login script for lazy migration from legacy user store  
**Supports:** bcrypt (current standard), MD5-salted (legacy — triggers password reset Action)  
**Returns:** Auth0 user profile object with `user_id: "legacy|{db_id}"` for deterministic migration

### Script 9-5: Custom Database Get User Script
**File:** `custom-db-getbyemail.js`  
**Purpose:** Auth0 Custom Database `getByEmail` script (required for password reset flows)  
**Note:** Must return `null` (not error) when user is not found — distinction matters for Auth0 flow

### Script 9-6: Post-Login Action — Profile Enrichment
**File:** `action-post-login-enrich.js`  
**Purpose:** Auth0 Action that adds organization context, external permissions, and adaptive MFA enforcement  
**Features:** Namespace-prefixed custom claims, fail-open for enrichment (fail-closed for explicit blocks), geo-blocking  
**Pattern:** External API call with error handling that does not lock out users on API failure

### Script 9-7: Tenant-as-Code Deployment
**File:** `deploy-tenant.sh`  
**Purpose:** Auth0 Deploy CLI commands for GitOps-style tenant configuration management  
**Commands:** export (current → YAML), import (YAML → tenant), environment-specific config  
**CI/CD:** GitHub Actions workflow for dev → staging → prod promotion

## Auth0 Deploy CLI Structure
```
tenant-config/
├── tenant.yaml              # Tenant settings (session lifetime, MFA policy)
├── clients/                 # Application definitions (one YAML per app)
├── connections/             # Database, social, enterprise connections
├── actions/                 # Actions code + metadata
│   └── post-login/
│       ├── code.js
│       └── action.yaml
├── apis/                    # Resource server (API) definitions
├── organizations/           # Organization configs (B2B)
└── pages/                   # Universal Login page templates
```

## Auth0 Management API Quick Reference
```bash
# Get Management API token (M2M)
curl -X POST "https://YOUR_DOMAIN/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=MGMT_CLIENT_ID&client_secret=MGMT_SECRET&audience=https://YOUR_DOMAIN/api/v2/"

# List all organizations
curl "https://YOUR_DOMAIN/api/v2/organizations" \
  -H "Authorization: Bearer $MGMT_TOKEN"

# Get user by email
curl "https://YOUR_DOMAIN/api/v2/users-by-email?email=user@example.com" \
  -H "Authorization: Bearer $MGMT_TOKEN"
```

## Related Chapter Content
- Auth0 tenant architecture: §9.1
- Universal Login (New vs Classic): §9.2
- Actions vs Rules: §9.4
- M2M Client Credentials: §9.5
- Organizations (`org_id` security): §9.6
- Attack Protection: §9.7
- Custom Database + Lazy Migration: §9.8
- Deployment models (Public vs Private Cloud): §9.9
- Migration playbook (legacy CIAM → Auth0): §9.10
