# Enterprise IAM Architecture: A Practitioner's Textbook

> A 12-chapter, hands-on guide to enterprise Identity and Access Management — from Active Directory fundamentals to AI identity security.

This repository contains the companion scripts, architecture artifacts, and lab guides for a complete enterprise IAM reference textbook. Every script is production-grade PowerShell or JavaScript/Python, tested against real enterprise environments. Every architecture decision record is traceable to a real business requirement.

---

## About This Work

This textbook was written from the perspective of a senior IAM architect designing and operating identity infrastructure at enterprise scale — 25,000 to 85,000 users, healthcare and financial services regulatory requirements, hybrid Active Directory and cloud-native Entra ID environments, and the full CIAM-to-PAM spectrum.

The companion case study — Vertex Health Systems (fictional) — runs through all twelve chapters: a $12.4B regional health system with 28 hospitals, 85,000 employees, 4.2M patients, and an 18-month Zero Trust modernization program following a supply chain ransomware near-miss.

---

## Chapters

| # | Title | Key Topics |
|---|---|---|
| 1 | Identity Foundations | AAA, JML, trust models, NIST SP 800-63, MFA taxonomy |
| 2 | Directory Services | AD DS architecture, Kerberos, NTLM, FSMO, GPO, trusts |
| 3 | PKI and Certificate Services | X.509, CA hierarchy, ADCS, ESC attacks, OCSP, WHfB |
| 4 | Federation and SSO | SAML 2.0, OAuth 2.0, OIDC, PKCE, JWT, AD FS |
| 5 | Privileged Access Management | CyberArk, HashiCorp Vault, JIT, LAPS, PAW, break-glass |
| 6 | Zero Trust Architecture | NIST 800-207, CISA pillars, CA design, CAE, ZTNA, SASE |
| 7 | IGA | JML automation, SCIM, RBAC/ABAC, SoD, access certification |
| 8 | Cloud Identity — Entra ID | PHS/PTA/Federation, App Reg, B2B, Managed Identity, Graph |
| 9 | CIAM — Auth0 | Tenant, Universal Login, Actions, M2M, Organizations, Attack Protection |
| 10 | ZT Implementation — Defender XDR | Identity Protection, CAE deep dive, Sentinel KQL, MSEM |
| 11 | CAD Capstone | IAM-ADR framework, end-to-end architecture, HIPAA/HITRUST mapping |
| 12 | AI Identity Security | LLM access control, AI workload identity, prompt injection defense |

---

## Technologies Covered

**Directory and Authentication**
- Microsoft Active Directory (AD DS, ADCS, AD FS)
- Microsoft Entra ID (formerly Azure AD) — P1/P2
- Kerberos, NTLM, LDAP, SAML 2.0, OAuth 2.0, OIDC, WS-Federation

**Privileged Access**
- CyberArk PAS (Digital Vault, PVWA, CPM, PSM, AIM)
- HashiCorp Vault (dynamic secrets, database engine)
- Microsoft Entra PIM

**Identity Governance**
- SailPoint IdentityNow
- Microsoft Entra ID Governance (Access Reviews)
- SCIM 2.0 provisioning

**CIAM**
- Auth0 (Okta) — Organizations, Actions, Custom DB, Attack Protection
- Microsoft Entra External ID

**Security Operations**
- Microsoft Defender XDR (MDI, MDE, MDCA, MDO)
- Microsoft Sentinel (SIEM/SOAR, KQL)
- Microsoft Security Exposure Management (MSEM)

**PKI**
- Microsoft ADCS (CA, NDES, Online Responder, Web Enrollment)
- DigiCert (ACME protocol automation)

**AI**
- Anthropic Claude API (claude-sonnet-4-6, claude-haiku-4-5)
- Microsoft Azure OpenAI
- RAG pipeline access control (Azure AI Search)

---

## Repository Structure

```
iam-textbook-portfolio/
├── README.md
├── .gitignore
├── CONTRIBUTING.md
├── scripts/
│   ├── chapter-02-directory/    # AD DS audit and attack surface scripts
│   ├── chapter-03-pki/          # PKI, ADCS, certificate lifecycle scripts
│   ├── chapter-05-pam/          # PAM, LAPS, PAW, break-glass scripts
│   ├── chapter-06-zerotrust/    # Conditional Access, CAE, ZT maturity scripts
│   ├── chapter-07-iga/          # IGA lifecycle, SoD, access certification scripts
│   ├── chapter-08-entra/        # Entra ID, Graph API, B2B, Managed Identity scripts
│   ├── chapter-09-auth0/        # Auth0 management, vendor access, M2M scripts
│   ├── chapter-10-defender/     # Sentinel KQL, Identity Protection, ZT baseline scripts
│   └── chapter-12-ai-security/  # AI identity, RAG access control, SoD gaming detection
├── architecture/
│   ├── adr/                     # Architecture Decision Records (Ch 11)
│   └── vertex-health/           # Vertex Health Systems capstone architecture
└── labs/
    └── README.md                # Hands-on lab index (all chapters)
```

---

## Script Highlights

**AD Attack Surface Audit** (`scripts/chapter-02-directory/`)
- Identify Kerberoastable accounts, AS-REP Roastable accounts, unconstrained delegation
- Detect dangerous userAccountControl flags at scale
- Audit trust relationships and SID filtering status
- Complete AD Health Dashboard (replication, FSMO, krbtgt age)

**PKI Vulnerability Detection** (`scripts/chapter-03-pki/`)
- Enumerate all certificate templates and flag ESC1, ESC2, ESC3 conditions
- Certificate expiry monitoring with 60/30-day warning thresholds
- WHfB and smart card enrollment audit
- ESC8 vulnerability detection (ADCS web enrollment over HTTP)

**Zero Trust Baseline** (`scripts/chapter-10-defender/`)
- Measure MFA coverage, legacy auth volume, risky user count, device compliance
- Conditional Access tiered policy gap analysis (Baseline/Identity/Device/Privileged/App)
- CAE revocation latency testing
- Sentinel KQL analytics rules for identity threat detection

**AI Identity Controls** (`scripts/chapter-12-ai-security/`)
- RAG pipeline with server-side document namespace access control
- AI agent delegation token pattern (orchestrator → sub-agent)
- Cumulative SoD gaming detection (temporal correlation)
- AI access review accuracy measurement (false negative rate tracking)

---

## How to Use

**For exam preparation:** Read chapter → complete hands-on labs → run self-check questions → review interview cheat-sheet. Each chapter is self-contained.

**For enterprise audits:** Navigate to the relevant chapter's script folder. Each script includes parameter documentation and produces CSV or JSON output suitable for audit evidence packages.

**For architecture work:** Start with the IAM-ADR Framework (Chapter 11). Use the Architecture Decision Record templates in `architecture/adr/` as the basis for your own ADRs.

**For AI/Claude API integration:** Chapter 12 scripts use the Anthropic Python SDK. Install with `pip install anthropic`. Set `ANTHROPIC_API_KEY` environment variable.

---

## Prerequisites

**PowerShell scripts:**
```powershell
# Required modules
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ActiveDirectory -Scope CurrentUser  # or use RSAT
Install-Module AzureAD -Scope CurrentUser           # legacy; prefer Microsoft.Graph
```

**Python scripts (Chapter 12):**
```bash
pip install anthropic azure-identity azure-search-documents cryptography PyJWT
```

**JavaScript scripts (Chapter 9 — Auth0):**
```bash
npm install node-fetch jsonwebtoken uuid auth0
```

---

## Compliance Coverage

| Framework | Chapters | Coverage |
|---|---|---|
| HIPAA Security Rule §164.312 | 3, 5, 7, 11 | Technical safeguards: unique user ID, auto logoff, encryption, audit controls |
| HITRUST CSF 11.x | 7, 11 | Access control domain: registration, privilege mgmt, review, revocation |
| SOX ITGC | 7 | Access control, change management, audit log retention (7 years) |
| PCI DSS v4.0 | 7 | Requirement 8: MFA, access reviews (semi-annual) |
| NIST SP 800-63 | 1 | IAL/AAL/FAL levels |
| NIST SP 800-207 | 6, 10 | Zero Trust tenets and implementation |
| NIST AI RMF | 12 | GOVERN/MAP/MEASURE/MANAGE for AI in IAM |
| OWASP LLM Top 10 | 12 | LLM01 (Prompt Injection), LLM08 (Excessive Agency) |
| ISO 27001 | 6, 7 | A.9 Access control, A.12 Operations |

---

## Author

**Lawrence** — Senior IAM Architect and AI Security Specialist

Specializing in enterprise identity modernization, Zero Trust architecture, and AI governance for regulated industries (healthcare, financial services).

- LinkedIn: [your-linkedin-url]
- GitHub: [your-github-url]
- Email: [your-email]

---

## License

Scripts and architecture artifacts are provided for educational and professional reference. Not for use in production without adaptation to your specific environment, compliance requirements, and security review.

---

*Built with Claude Code — Anthropic's AI-powered development environment.*
