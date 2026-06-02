# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) from Chapter 11: CAD Capstone. Each ADR documents a significant design decision for the Vertex Health Systems IAM modernization program.

## ADR Format

```markdown
---
ADR-{number}: {Decision title}
Status:        Proposed | Accepted | Deprecated | Superseded by ADR-N
Date:          YYYY-MM-DD
Review date:   YYYY-MM-DD
---

## Context
What is the situation that requires a decision? What forces are at play?
Which business requirements or constraints drive this decision?

## Decision
What have we decided to do?

## Rationale
Why did we choose this over the alternatives considered?
What alternatives were evaluated and rejected, and why?

## Consequences
### Positive
- What becomes easier?

### Negative
- What becomes harder?
- What new decisions are now required?

### Neutral
- What must now be monitored or managed?
```

## ADR Index — Vertex Health Systems

| ADR | Title | Status | Review Date |
|---|---|---|---|
| ADR-01 | Forest Consolidation Strategy | Accepted | 2027-06-01 |
| ADR-02 | Hybrid Authentication Model (PHS vs AD FS) | Accepted | 2026-12-01 |
| ADR-03 | PKI Hierarchy (Two-Tier vs Three-Tier) | Accepted | 2030-01-01 |
| ADR-04 | Federation Platform (Entra ID vs AD FS replacement) | Accepted | 2027-06-01 |
| ADR-05 | Privileged Access Management Platform (CyberArk) | Accepted | 2027-01-01 |
| ADR-06 | IGA Platform (SailPoint IdentityNow) | Accepted | 2028-06-01 |
| ADR-07 | Patient Portal CIAM (Entra External ID vs Auth0) | Accepted | 2026-12-01 |
| ADR-08 | Zero Trust Implementation Model | Accepted | 2027-01-01 |

## Key Decision Themes

### Security vs. Availability Trade-offs
**ADR-02 (Hybrid Auth):** PHS chosen over AD FS. AD FS creates an on-premises single point of failure for cloud authentication — incompatible with a 99.99% SLA at remote hospital sites with 1.5 Mbps WAN links. PHS validates in the cloud; WAN outage does not break authentication.

### Compliance Driving Product Selection
**ADR-07 (CIAM):** Auth0 Private Cloud was rejected despite superior developer experience because HIPAA BAA for Auth0 requires Private Cloud deployment at 3-5x cost. Microsoft Entra External ID provides HIPAA BAA coverage on standard Azure US-region deployment within the approved budget envelope.

### Vendor Consolidation vs. Best-of-Breed
**ADR-05 (PAM):** CyberArk selected over HashiCorp Vault for primary PAM because CyberArk is the only platform with certified Epic EHR connector, native 3270 mainframe session proxy, and HIPAA BAA on its SaaS offering. HashiCorp Vault used for dynamic secrets in DevOps pipelines (separate, complementary deployment).

### On-Premises Dependency Minimization
**ADR-04 (Federation):** No new AD FS deployment. All 400 applications migrated to Entra ID SAML/OIDC. Legacy LDAP-only applications moved to Azure IaaS + Entra Domain Services rather than maintaining on-premises federation infrastructure.

## The IAM Architecture Forces

Every ADR weighs the seven IAM architecture forces:

| Force | Weight for Vertex Health |
|---|---|
| Security | High — HIPAA, ransomware history, clinical data sensitivity |
| Usability | High — clinical staff cannot tolerate authentication friction (8-second SLA) |
| Compliance | Critical — HIPAA BAA required from all identity vendors handling PHI |
| Operability | Medium — IT team of 45; cannot maintain complex on-prem auth infrastructure |
| Scalability | Medium — 85,000 users + 4.2M patients; Auth0-scale CIAM required |
| Cost | Constrained — $8.2M Year 1 hard budget ceiling |
| Vendor lock-in | Low — Microsoft stack already dominant; incremental lock-in acceptable |

## Using These ADRs as Templates

These ADRs are designed to be adapted for your own environment. When creating a new ADR:

1. Replace Vertex Health context with your organization's specific situation
2. Update the constraints table (your regulatory requirements, budget, team size)
3. Evaluate the same alternatives with your actual requirements
4. Set a realistic review date (decisions should be revisited as the environment changes)

The value of an ADR is not the decision itself — it is the reasoning that future engineers can read to understand why the system is the way it is.
