# Vertex Health Systems — Capstone Architecture

The Vertex Health Systems case study is the fictional enterprise used throughout Chapter 11 to demonstrate a complete, production-grade IAM architecture design. It is deliberately complex — representative of the constraints, legacy debt, and regulatory requirements found in large healthcare organizations.

## Organization Profile

| Attribute | Value |
|---|---|
| Industry | Healthcare — regional health system |
| Size | 85,000 employees |
| Facilities | 28 hospitals, 340 outpatient clinics |
| Patient records | 4.2 million (HIPAA covered entity) |
| Annual revenue | $12.4 billion |
| IT team | 45 identity/security engineers |
| Program trigger | Supply chain ransomware near-miss (14-day dwell time, vendor VPN account, no MFA) |

## Starting State (Pre-Program)

| Component | Legacy State |
|---|---|
| Directory | Windows Server 2016 AD DS — 4 forests, 18 domains (hospital acquisitions) |
| Federation | Oracle OAM — end-of-life in 18 months |
| CIAM | Homegrown PHP — 3.8M patient portal accounts |
| PAM | None — static vendor passwords, no session recording |
| IGA | None — manual provisioning, 12 HR systems |
| PKI | Mixed: public CA, self-signed, expired certs on internal apps |
| Zero Trust | None — perimeter model, VPN access |
| MFA | None for most users |
| Dwell time | 14 days (supply chain incident) |

## Business Requirements (Key)

| ID | Requirement | Priority |
|---|---|---|
| BR-01 | Clinical staff auth < 8 seconds at point of care | Critical |
| BR-02 | Patient portal: 3.8M patients, mobile-first, social login | Critical |
| BR-03 | HIPAA BAA for all identity infrastructure | Critical |
| BR-04 | 99.99% authentication availability (52 min/year downtime) | Critical |
| BR-05 | Third-party vendor: MFA + time-bounded + auditable | High |
| BR-06 | Employee deprovisioning within 4 hours of HR event | High |
| BR-07 | SOC 2 Type II + HITRUST CSF within 24 months | High |
| BR-08 | Clinical workstation shared login (tap-and-go badge) | High |

## Target Architecture Components

### Identity Foundation
- **Directory:** `vertex-health.internal` — single consolidated forest with 4 child domains (corp, clinical, ops, privileged)
- **Hybrid auth:** Password Hash Sync + Seamless SSO (PHS chosen over AD FS for WAN resilience)
- **Entra ID:** Single tenant, US region, Entra ID P2

### PKI
- Offline Root CA (air-gapped, HSM, physical safe)
- InternalIssuing-01 (smart card logon, user auth, code signing)
- InternalIssuing-02 (workstation, MDM, 802.1X, SCEP via Intune)
- DigiCert via ACME (public TLS: `*.vertex-health.com`)

### Clinical Authentication (8-second SLA)
- HID proximity badge with PIV-compliant X.509 certificate
- Imprivata OneSign agent on clinical workstations
- PKINIT → Kerberos TGT → Seamless SSO → Entra ID token → Epic EHR
- Result: 3.7 seconds (LAN), 5.1 seconds (WAN) — both under 8-second SLA

### Federation
- Entra ID replaces Oracle OAM (400 apps migrated)
- Application triage: Bucket A (280 apps, SAML/OIDC), Bucket B (65, WS-Fed/Kerberos), Bucket C (40, LDAP→Entra Domain Services), Bucket D (15, PAM session proxy)

### PAM
- CyberArk PAS (Cloud vault, US-East)
- On-premises CPM (password rotation) + PSM (session proxy including 3270 mainframe)
- AIM (eliminates hardcoded application credentials)
- Vendor access: B2B guest + CA + PSM — vendor never sees credential

### IGA
- SailPoint IdentityNow (SaaS, HIPAA BAA)
- Workday HCM integration (24-month target) / MuleSoft interim (12 CSVs)
- Automated JML: Joiner ≤ 2 hours, Leaver ≤ 4 hours
- Quarterly access certifications across all 28 hospitals

### CIAM
- Microsoft Entra External ID (HIPAA BAA on Azure US region — Auth0 Private Cloud rejected on cost)
- Custom domain: `id.myvertexhealth.com`
- Social: Google, Apple, Facebook, Microsoft consumer
- MFA: Email OTP (default) + optional TOTP app

### Zero Trust
- Identity first: MFA + legacy auth block (Month 1-3)
- Risk-based CA: Identity Protection integration (Month 3-6)
- Device compliance: Intune + MDCA session controls (Month 6-9)
- Sentinel SIEM with UEBA Fusion ML (Month 9-12)
- MSEM: Weekly top-20 attack path review

## Program Outcomes (Month 24)

| Metric | Baseline | Target | Achieved |
|---|---|---|---|
| CISA ZT Identity Pillar | Traditional | Optimal | Optimal |
| MFA coverage | 0% | >95% | 97.2% |
| Dwell time (MTTD) | 14 days | <4 hours | 2.8 hours |
| MTTR (high-severity) | Unknown | <4 hours | 2.8 hours |
| Legacy auth sign-ins | ~12,400/day | <50/day | 23/day |
| Attack paths (MSEM critical) | 847 | <100 | 89 |
| HITRUST CSF | Not certified | Certified | Certified |
| SOC 2 Type II | Not certified | In progress | Observation period active |
| Cyber insurance | At risk | Renewed | Renewed (Month 3 — MFA proof) |

## Architecture Diagram

See `vertex-health-architecture.md` for the full ASCII architecture diagram from Chapter 11 §11.4, showing the complete target-state topology across identity sources, Entra ID control plane, security layer, PAM layer, IGA layer, PKI layer, and access consumer groups.

## Lessons Learned

1. **Clinical workflow before technology:** The 90-day union notice requirement (constraint C-07) meant stakeholder engagement had to begin in Month 6 for a Month 9 authentication change. Technology was ready; politics was the critical path.

2. **PHS resilience proved itself:** Two WAN outages during the program (Month 4, Month 11) had zero impact on cloud authentication for PHS-migrated users. AD FS users in the legacy environment were disrupted both times.

3. **Vendor access was the highest-ROI control:** The supply chain incident that triggered the program came from a vendor VPN account. The vendor access redesign (B2B + PSM + time-bounded + auto-revoke) was implemented in Month 6 and immediately closed the class of attack that caused the incident.

4. **IGA interim state is fragile:** The MuleSoft-aggregated 12-CSV HR integration broke twice in the first quarter. Accelerating the ERP consolidation to provide a single HR source of truth should have been a program dependency, not a parallel track.
