# Hands-On Labs

Each chapter includes 3-4 hands-on labs designed to be completed in a Microsoft 365 Developer tenant (free) or Auth0 free tier. Labs escalate in complexity within each chapter.

## Environment Setup

**Free lab environments:**
- Microsoft 365 Developer Program: developer.microsoft.com/microsoft-365/dev-program (free E5 tenant, 25 users)
- Entra ID P2 trial: 30-day free trial from the Entra ID portal
- Auth0 free tier: auth0.com (7,000 MAU, unlimited Actions, 2 social connections)
- Anthropic API: console.anthropic.com (pay-per-token; use claude-haiku-4-5 for lowest cost)

---

## Chapter 2: Directory Services Labs

### Lab 2-A: FSMO Role Enumeration
Identify all FSMO role holders in your lab forest. Verify Infrastructure Master is not co-located with the Global Catalog server. Document the role holder for each of the five roles.

### Lab 2-B: Kerberos Attack Surface Audit
Run Script 2-7 against your lab domain. Identify any accounts with SPNs (Kerberoastable), accounts with pre-auth disabled (AS-REP Roastable), and any unconstrained delegation configurations. Remediate one finding.

### Lab 2-C: GPO Inheritance Analysis
Create a test OU structure with Block Inheritance on one OU. Use RSoP (resultant set of policy) to verify which GPOs apply at each level. Document the LSDOU processing order.

### Lab 2-D: Trust Enumeration
If you have a multi-domain lab: enumerate all trusts and verify SID filtering status. If single-domain: simulate the trust audit query and document what you would look for.

---

## Chapter 3: PKI Labs

### Lab 3-A: Certificate Template Vulnerability Scan
Run Script 3-3 against your lab ADCS environment (or an ADCS lab VM). Identify any templates with `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT` enabled. Document whether Client Auth EKU is also present.

### Lab 3-B: OCSP Stapling Verification
Using OpenSSL, test a public website for OCSP Stapling: `openssl s_client -connect example.com:443 -status`. Verify the OCSP response is included in the TLS handshake. Test a site without stapling and compare.

### Lab 3-C: Certificate Chain Validation
Using `certutil -verify` (Windows) or `openssl verify` (Linux), validate a certificate chain for a public website. Identify each certificate in the chain (leaf, intermediate, root). Verify the AIA and CDP URLs.

### Lab 3-D: Smart Card Enrollment Simulation
In your lab, create a certificate template for User Authentication. Configure autoenrollment via GPO. Force autoenrollment on a test machine (`certutil -pulse`). Verify the certificate appears in the user's Personal store.

---

## Chapter 4: Federation and SSO Labs

### Lab 4-A: JWT Decode and Validation
Obtain an ID token from your Entra ID developer tenant (use the Graph Explorer). Decode it at jwt.io. Verify: algorithm, issuer, audience, expiry, subject, `nonce` presence. Write the validation checklist from memory and compare.

### Lab 4-B: OAuth 2.0 Authorization Code + PKCE
Using a Node.js or Python app, implement Authorization Code + PKCE flow against Entra ID. Log the `code_verifier`, `code_challenge`, and token exchange. Verify PKCE prevents code interception by changing the verifier at exchange time.

### Lab 4-C: SAML Assertion Decode
Using a SAML test application (Okta Developer or Auth0 lab), capture a SAML Response. Base64-decode the assertion. Identify: Issuer, NameID, Conditions (NotBefore/NotOnOrAfter), AttributeStatement, Signature. Verify the time window.

### Lab 4-D: Entra ID App Registration and API Permission
Create an App Registration in your developer tenant. Add `User.Read` (delegated) and `User.ReadBasic.All` (application) permissions. Note which requires admin consent and which does not. Acquire tokens for both and compare the `scp` vs. `roles` claims.

---

## Chapter 5: PAM Labs

### Lab 5-A: Azure PIM Eligible Role Assignment
In your Entra ID P2 trial, configure a test user as eligible for the User Administrator role (not permanently active). Activate the role as the test user — observe the activation workflow, MFA requirement, and justification prompt. Verify the activation appears in the PIM audit log.

### Lab 5-B: PowerShell Script Block Logging
Enable Script Block Logging via registry on a test Windows machine (Script 5-4). Run a PowerShell command. Find the Event ID 4104 log entry in Event Viewer. Note what information is captured.

### Lab 5-C: Windows LAPS Configuration
Enable Windows LAPS on a lab domain-joined machine via GPO. Verify the `msLAPS-Password` attribute is populated in AD. Retrieve the password using `Get-LapsADPassword`. Verify retrieval is logged in Event Viewer.

### Lab 5-D: Break-Glass Account Audit
In your Entra ID tenant, identify any existing break-glass accounts (or create a test one). Verify: cloud-only (not synced), FIDO2-only authentication method, excluded from at least one CA policy. Document what alert you would create in Sentinel for any break-glass sign-in.

---

## Chapter 6: Zero Trust Labs

### Lab 6-A: Conditional Access Risk-Based Policy
In your Entra ID P2 trial, create a CA policy targeting Sign-in Risk = Medium with MFA grant. Set to Report-Only. Use the "What If" tool (CA → What If) to simulate a medium-risk sign-in. Verify the policy would trigger. Note what would need to happen before enforcing.

### Lab 6-B: Named Location Configuration
Create a Named Location in Entra ID for a trusted IP range (e.g., your home IP). Create a CA policy that exempts this location from MFA. Test: sign in from the trusted IP (no MFA prompt) vs. a different network (MFA prompt).

### Lab 6-C: CAE Session Revocation Test
Using a test account logged into Outlook Web App, run `Invoke-MgInvalidateAllUserRefreshToken` for that user. Time how long before OWA shows a re-authentication prompt. Record the result as your CAE baseline metric.

### Lab 6-D: Zero Trust Maturity Self-Assessment
Run Script 6-6 (ZT Maturity Self-Assessment) for your lab tenant. Record your scores across the five CISA pillars. Identify the lowest-scoring pillar and document two specific controls that would advance it to the next maturity level.

---

## Chapter 7: IGA Labs

### Lab 7-A: Leaver Automation Script
Using Script 7-1 in your lab AD, simulate a Leaver event for a test user: disable account, remove group memberships, log actions, revoke Entra sessions. Verify each step completed. Measure total script execution time vs. the 4-hour SLA.

### Lab 7-B: SoD Violation Detection
Create two AD groups representing conflicting entitlements (e.g., `GRP-AP-CreateVendor` and `GRP-AP-ApprovePayment`). Add a test user to both. Run Script 7-5 with a SoD matrix CSV. Verify the violation is detected and reported.

### Lab 7-C: SCIM Endpoint Test
Using Script 7-3, test a SCIM endpoint (use a free SaaS app with SCIM support, e.g., Slack free tier or a mock SCIM server). Run the full Create/Read/Patch/Delete lifecycle. Verify `externalId` is round-tripped correctly.

### Lab 7-D: Access Certification Data Generation
Run Script 7-6 against your lab AD. Generate certification data for 5-10 test users. Add simulated last-use dates and peer comparison data. Export the JSON. Review the output and assess whether a manager reviewing this would have enough context to make a real decision.

---

## Chapter 8: Entra ID Labs

### Lab 8-A: App Registration Security Audit
Run Script 8-3 against your developer tenant. Identify any App Registrations with: expiring secrets, no owners, Application permissions granted. For each finding, document the remediation action.

### Lab 8-B: B2B Guest Invitation
Invite an external email address as a B2B guest to your tenant. Assign the guest to a specific application (not All Users). Check the guest's `ExternalUserState`. After 5 minutes, run Script 8-5 to find "stale" guests — verify your new guest appears correctly.

### Lab 8-C: Managed Identity Token Acquisition
Create an Azure VM with a System-assigned Managed Identity. From within the VM, query the IMDS endpoint to obtain a token: `curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/' -H Metadata:true`. Decode the token and identify the `sub` and `oid` claims.

### Lab 8-D: Graph API Delta Query
Run Script 8-9 to perform an initial Graph delta query for users. Record the delta link. Make a change to a user (e.g., update display name). Run the delta query again using the saved delta link. Verify only the changed user appears in results.

---

## Chapter 9: Auth0 Labs

### Lab 9-A: Auth0 Universal Login Setup
Create a free Auth0 tenant. Switch to New Universal Login. Create a Regular Web Application. Configure primary color and logo. Test the login flow from a simple HTML page using the Auth0 SPA SDK.

### Lab 9-B: Post-Login Action Deployment
Create a Post-Login Action in your Auth0 tenant. Add a custom claim to the ID token using a namespaced URI (`https://yourapp.com/department`). Deploy the Action. Decode the resulting ID token at jwt.io and verify the custom claim is present.

### Lab 9-C: M2M Application and Token Caching
Create a Machine-to-Machine application in Auth0. Create an API (Resource Server) with two scopes. Implement the token cache class from Script 9-3. Verify: token is requested once, cached, and reused across 10 simulated API calls. Verify cache refresh fires 60 seconds before expiry.

### Lab 9-D: Custom Database Connection
Create a Custom Database connection in Auth0 with Import Users enabled. Implement the login script using the simulated user store from Chapter 9 §9.14 Lab 9-D. Log in as a test user. Verify the user appears in Auth0's User Management after first login (lazy migration completed).

---

## Chapter 10: Defender XDR Labs

### Lab 10-A: Risk-Based Conditional Access
Create a CA policy for Sign-in Risk ≥ Medium → Require MFA. Set to Report-Only. Use the CA "What If" tool to simulate a medium-risk sign-in. Verify the policy triggers. After validating no false positives in the report-only logs, document the steps to enforce.

### Lab 10-B: Sentinel Analytics Rule
Deploy the impossible travel KQL rule from Chapter 10 §10.7 to your Sentinel workspace. Set a 5-minute schedule. Generate a test event (sign in from two different IP geolocation providers within 60 minutes). Verify the rule triggers and creates an incident.

### Lab 10-C: Zero Trust Baseline Assessment
Run Script 10-5 against your developer tenant. Record the JSON output. Identify your three lowest scores. For each: document the specific control that would improve the score and estimate the implementation effort.

### Lab 10-D: CAE Revocation Latency
With a test user logged into Outlook Web App, run `Invoke-MgInvalidateAllUserRefreshToken`. Start a stopwatch. Watch OWA. Record the time until the sign-in prompt appears. If > 60 seconds, document what might explain the delay (legacy auth client, non-CAE resource, etc.).

---

## Chapter 11: Capstone Labs

### Lab 11-A: Architecture Decision Record
Write an ADR for a real or hypothetical decision in your organization using the template from `architecture/adr/README.md`. The decision can be: hybrid auth model selection, PAM platform choice, CIAM platform selection, or ZT implementation sequence. Get peer feedback on the rationale section.

### Lab 11-B: Compliance Control Mapping
Using the HIPAA §164.312 mapping table from Chapter 11 §11.7 as a template, map three controls from your current environment to specific HIPAA or HITRUST requirements. For each: identify the implementation and what evidence you would provide to an auditor.

### Lab 11-C: Vendor Access Proof of Concept
Using Script 9-2 (or the manual steps from Chapter 11 §11.6), provision a B2B guest account with: time-bounded access (2 hours), specific group assignment, automatic expiry check. Verify the account is disabled after the expiry time. Document the audit trail.

### Lab 11-D: Board ROI Presentation
Using the framework from Chapter 11 Q3 self-check, build a 3-slide board summary for a Zero Trust program: (1) quantified risk before controls (use IBM Cost of Breach data for your industry), (2) what the program delivers, (3) investment vs. risk reduction expressed in dollar terms.

---

## Chapter 12: AI Identity Security Labs

### Lab 12-A: RAG Access Control
Using Script 12-1 as a base, build a simple RAG query that retrieves documents from a mock data store. Implement two namespace levels (public, internal). Verify that a user in only the "public" group cannot retrieve "internal" documents — test with a query designed to cross the boundary.

### Lab 12-B: Prompt Injection Defense
Using Script 12-4 as a base, build a simple email triage agent with a `send_email` tool. Attempt a prompt injection via a crafted "email" that instructs the agent to send an email to an attacker address. Verify the defense layers catch the injection before the tool executes.

### Lab 12-C: AI Access Review
Using Script 12-7, generate AI recommendations for 10 simulated access certification items. Include at least: one never-used entitlement, one peer-outlier entitlement, one SoD conflict. Verify the AI recommends REVOKE for the appropriate items and provides reasoning.

### Lab 12-D: SoD Gaming Detection
Using Script 12-5, feed it a simulated access request history for a test user who has requested entitlements in two conflicting SoD zones over 6 months, evenly spaced. Verify the script detects: (1) the SoD zone conflict, (2) the suspicious regularity pattern (low standard deviation of intervals).

---

*Total labs: 48 across 12 chapters. Estimated time per lab: 30-60 minutes. Full completion: approximately 30-45 hours of hands-on practice.*
