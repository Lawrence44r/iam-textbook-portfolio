"""
Enterprise IAM Architecture Textbook — Word Document Generator
Font: Segoe UI 10pt throughout
Features: Table of Contents, Analogy boxes inline, Inline citations [N], Reference list at end
Run: python generate_textbook_doc.py
Output: IAM_Textbook_Enterprise_Architecture.docx
"""

from docx import Document
from docx.shared import Pt, RGBColor, Inches, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.style import WD_STYLE_TYPE
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import copy

OUTPUT_FILE = "IAM_Textbook_Enterprise_Architecture.docx"
FONT_NAME   = "Segoe UI"
BODY_SIZE   = Pt(10)

# ─────────────────────────────────────────────────────────────
# COLOUR PALETTE
# ─────────────────────────────────────────────────────────────
CLR_DARK_BLUE  = RGBColor(0x1F, 0x39, 0x64)   # Chapter headings
CLR_MID_BLUE   = RGBColor(0x2E, 0x74, 0xB5)   # Section headings
CLR_ACCENT     = RGBColor(0x70, 0xAD, 0x47)   # Key term highlight
CLR_ANALOGY_BG = "FFF2CC"                      # Analogy box fill (yellow)
CLR_NOTE_BG    = "DEEAF1"                      # Info/note box fill (blue)
CLR_WARN_BG    = "FCE4D6"                      # Warning box fill (orange)
CLR_CODE_BG    = "F2F2F2"                      # Code block fill (grey)
CLR_WHITE      = "FFFFFF"

# ─────────────────────────────────────────────────────────────
# REFERENCE DATABASE
# ─────────────────────────────────────────────────────────────
REFERENCES = {
    1:  "NIST SP 800-63-3, \"Digital Identity Guidelines,\" National Institute of Standards and Technology, 2017. https://pages.nist.gov/800-63-3/",
    2:  "NIST SP 800-207, \"Zero Trust Architecture,\" National Institute of Standards and Technology, 2020. https://doi.org/10.6028/NIST.SP.800-207",
    3:  "RFC 6749, \"The OAuth 2.0 Authorization Framework,\" IETF, 2012. https://datatracker.ietf.org/doc/html/rfc6749",
    4:  "RFC 7519, \"JSON Web Token (JWT),\" IETF, 2015. https://datatracker.ietf.org/doc/html/rfc7519",
    5:  "OASIS, \"Assertions and Protocols for the OASIS Security Assertion Markup Language (SAML) V2.0,\" 2005. https://docs.oasis-open.org/security/saml/v2.0/",
    6:  "CISA, \"Zero Trust Maturity Model v2.0,\" Cybersecurity and Infrastructure Security Agency, 2023. https://www.cisa.gov/zero-trust-maturity-model",
    7:  "NIST AI 100-1, \"Artificial Intelligence Risk Management Framework (AI RMF 1.0),\" National Institute of Standards and Technology, 2023. https://doi.org/10.6028/NIST.AI.100-1",
    8:  "Microsoft, \"What is Microsoft Entra ID?,\" Microsoft Learn, 2024. https://learn.microsoft.com/en-us/entra/fundamentals/whatis",
    9:  "Auth0, \"Auth0 Documentation,\" Okta, 2024. https://auth0.com/docs",
    10: "HITRUST Alliance, \"HITRUST CSF,\" 2023. https://hitrustalliance.net/hitrust-csf/",
    11: "Sayer, O. et al., \"Certified Pre-Owned: Abusing Active Directory Certificate Services,\" SpecterOps, 2021. https://posts.specterops.io/certified-pre-owned-d95910965cd2",
    12: "MITRE ATT&CK, \"Enterprise Matrix,\" MITRE, 2024. https://attack.mitre.org/matrices/enterprise/",
    13: "RFC 7644, \"System for Cross-domain Identity Management: Protocol,\" IETF, 2015. https://datatracker.ietf.org/doc/html/rfc7644",
    14: "OWASP, \"OWASP Top 10 for Large Language Model Applications,\" 2023. https://owasp.org/www-project-top-10-for-large-language-model-applications/",
    15: "Kerberos Working Group, RFC 4120, \"The Kerberos Network Authentication Service (V5),\" IETF, 2005. https://datatracker.ietf.org/doc/html/rfc4120",
    16: "Microsoft, \"How PHS works,\" Microsoft Learn, 2024. https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-password-hash-synchronization",
    17: "NIST SP 800-53 Rev 5, \"Security and Privacy Controls for Information Systems and Organizations,\" NIST, 2020. https://doi.org/10.6028/NIST.SP.800-53r5",
    18: "SailPoint, \"The Definitive Guide to Identity Governance and Administration,\" SailPoint Technologies, 2023. https://www.sailpoint.com/identity-library/",
    19: "CyberArk, \"Privileged Access Management,\" CyberArk Software, 2024. https://www.cyberark.com/resources/",
    20: "Microsoft, \"Continuous Access Evaluation,\" Microsoft Learn, 2024. https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-continuous-access-evaluation",
    21: "OpenID Foundation, \"OpenID Connect Core 1.0,\" 2014. https://openid.net/specs/openid-connect-core-1_0.html",
    22: "X.509, \"Information technology – Open Systems Interconnection – The Directory: Public-key and attribute certificate frameworks,\" ITU-T, 2019.",
    23: "Litan, A. and Wheatman, V., \"Magic Quadrant for Access Management,\" Gartner, 2024.",
    24: "HIPAA, \"Security Rule (45 CFR Part 164),\" U.S. Department of Health and Human Services. https://www.hhs.gov/hipaa/for-professionals/security/",
    25: "SOX, \"Sarbanes-Oxley Act of 2002,\" U.S. Congress, 2002. https://www.sec.gov/about/laws/soa2002.pdf",
    26: "Shostack, A., \"Threat Modeling: Designing for Security,\" Wiley, 2014.",
    27: "NIST SP 800-190, \"Application Container Security Guide,\" NIST, 2017. https://doi.org/10.6028/NIST.SP.800-190",
    28: "RFC 7636, \"Proof Key for Code Exchange by OAuth Public Clients (PKCE),\" IETF, 2015. https://datatracker.ietf.org/doc/html/rfc7636",
    29: "NIST SP 800-145, \"The NIST Definition of Cloud Computing,\" NIST, 2011. https://doi.org/10.6028/NIST.SP.800-145",
    30: "Microsoft, \"Microsoft Sentinel Documentation,\" Microsoft Learn, 2024. https://learn.microsoft.com/en-us/azure/sentinel/",
}

# ─────────────────────────────────────────────────────────────
# LOW-LEVEL XML HELPERS
# ─────────────────────────────────────────────────────────────
def set_cell_bg(cell, hex_color):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd  = OxmlElement("w:shd")
    shd.set(qn("w:val"),   "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"),  hex_color)
    tcPr.append(shd)

def add_toc_field(doc):
    """Insert a TOC field that Word will populate on open / Ctrl+A, F9."""
    para  = doc.add_paragraph()
    run   = para.add_run()
    fldCh = OxmlElement("w:fldChar")
    fldCh.set(qn("w:fldCharType"), "begin")
    run._r.append(fldCh)

    instrR = para.add_run()
    instrT = OxmlElement("w:instrText")
    instrT.set(qn("xml:space"), "preserve")
    instrT.text = ' TOC \\o "1-3" \\h \\z \\u '
    instrR._r.append(instrT)

    fldCh2 = OxmlElement("w:fldChar")
    fldCh2.set(qn("w:fldCharType"), "separate")
    para.add_run()._r.append(fldCh2)

    fldCh3 = OxmlElement("w:fldChar")
    fldCh3.set(qn("w:fldCharType"), "end")
    para.add_run()._r.append(fldCh3)

def set_para_font(para, size=BODY_SIZE, bold=False, italic=False,
                  color=None, name=FONT_NAME):
    for run in para.runs:
        run.font.name  = name
        run.font.size  = size
        run.font.bold  = bold
        run.font.italic = italic
        if color:
            run.font.color.rgb = color

# ─────────────────────────────────────────────────────────────
# STYLE HELPERS
# ─────────────────────────────────────────────────────────────
def setup_styles(doc):
    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = FONT_NAME
    normal.font.size = BODY_SIZE

    for h_name, size, color in [
        ("Heading 1", Pt(16), CLR_DARK_BLUE),
        ("Heading 2", Pt(13), CLR_MID_BLUE),
        ("Heading 3", Pt(11), CLR_MID_BLUE),
    ]:
        try:
            h = styles[h_name]
        except KeyError:
            h = styles.add_style(h_name, WD_STYLE_TYPE.PARAGRAPH)
        h.font.name      = FONT_NAME
        h.font.size      = size
        h.font.bold      = True
        h.font.color.rgb = color
        h.paragraph_format.space_before = Pt(14)
        h.paragraph_format.space_after  = Pt(6)

# ─────────────────────────────────────────────────────────────
# CONTENT HELPERS
# ─────────────────────────────────────────────────────────────
def h1(doc, text):
    p = doc.add_heading(text, level=1)
    p.runs[0].font.name  = FONT_NAME
    p.runs[0].font.color.rgb = CLR_DARK_BLUE
    return p

def h2(doc, text):
    p = doc.add_heading(text, level=2)
    for r in p.runs:
        r.font.name  = FONT_NAME
        r.font.color.rgb = CLR_MID_BLUE
    return p

def h3(doc, text):
    p = doc.add_heading(text, level=3)
    for r in p.runs:
        r.font.name  = FONT_NAME
        r.font.color.rgb = CLR_MID_BLUE
    return p

def body(doc, text, bold_phrases=None):
    """Add a body paragraph. bold_phrases is a list of substrings to bold."""
    if bold_phrases:
        para = doc.add_paragraph()
        remaining = text
        for phrase in bold_phrases:
            idx = remaining.find(phrase)
            if idx == -1:
                continue
            if idx > 0:
                r = para.add_run(remaining[:idx])
                r.font.name = FONT_NAME
                r.font.size = BODY_SIZE
            br = para.add_run(phrase)
            br.font.name = FONT_NAME
            br.font.size = BODY_SIZE
            br.bold = True
            remaining = remaining[idx + len(phrase):]
        if remaining:
            r = para.add_run(remaining)
            r.font.name = FONT_NAME
            r.font.size = BODY_SIZE
    else:
        para = doc.add_paragraph(text)
        for r in para.runs:
            r.font.name = FONT_NAME
            r.font.size = BODY_SIZE
    para.paragraph_format.space_after = Pt(6)
    return para

def cite(doc, text, ref_nums):
    """Body paragraph ending with inline citation(s) e.g. [1][2]."""
    refs = "".join(f"[{n}]" for n in ref_nums)
    para = doc.add_paragraph()
    r1   = para.add_run(text + " ")
    r1.font.name = FONT_NAME
    r1.font.size = BODY_SIZE
    r2   = para.add_run(refs)
    r2.font.name  = FONT_NAME
    r2.font.size  = Pt(8)
    r2.font.color.rgb = CLR_MID_BLUE
    r2.font.bold  = True
    para.paragraph_format.space_after = Pt(6)
    return para

def bullet(doc, text, level=0):
    style = "List Bullet" if level == 0 else "List Bullet 2"
    try:
        para = doc.add_paragraph(text, style=style)
    except KeyError:
        para = doc.add_paragraph(f"• {text}")
    for r in para.runs:
        r.font.name = FONT_NAME
        r.font.size = BODY_SIZE
    return para

def analogy_box(doc, title, text):
    """Yellow shaded box for analogy explanations."""
    tbl = doc.add_table(rows=1, cols=1)
    tbl.style = "Table Grid"
    cell = tbl.cell(0, 0)
    set_cell_bg(cell, CLR_ANALOGY_BG)
    p1 = cell.paragraphs[0]
    r_icon  = p1.add_run("💡  ANALOGY — ")
    r_icon.font.name  = FONT_NAME
    r_icon.font.size  = BODY_SIZE
    r_icon.font.bold  = True
    r_icon.font.color.rgb = RGBColor(0x7F, 0x60, 0x00)
    r_title = p1.add_run(title.upper())
    r_title.font.name  = FONT_NAME
    r_title.font.size  = BODY_SIZE
    r_title.font.bold  = True
    r_title.font.color.rgb = RGBColor(0x7F, 0x60, 0x00)
    p2 = cell.add_paragraph(text)
    for r in p2.runs:
        r.font.name   = FONT_NAME
        r.font.size   = BODY_SIZE
        r.font.italic = True
    doc.add_paragraph()  # spacing after box
    return tbl

def note_box(doc, title, text):
    """Blue shaded informational box."""
    tbl  = doc.add_table(rows=1, cols=1)
    tbl.style = "Table Grid"
    cell = tbl.cell(0, 0)
    set_cell_bg(cell, CLR_NOTE_BG)
    p1 = cell.paragraphs[0]
    r1 = p1.add_run(f"ℹ  {title.upper()}")
    r1.font.name = FONT_NAME
    r1.font.size = BODY_SIZE
    r1.font.bold = True
    r1.font.color.rgb = CLR_DARK_BLUE
    p2 = cell.add_paragraph(text)
    for r in p2.runs:
        r.font.name = FONT_NAME
        r.font.size = BODY_SIZE
    doc.add_paragraph()
    return tbl

def interview_box(doc, questions):
    """Interview cheat-sheet at end of each chapter."""
    tbl  = doc.add_table(rows=1, cols=1)
    tbl.style = "Table Grid"
    cell = tbl.cell(0, 0)
    set_cell_bg(cell, "E2EFDA")
    p1 = cell.paragraphs[0]
    r1 = p1.add_run("🎯  INTERVIEW CHEAT SHEET")
    r1.font.name = FONT_NAME
    r1.font.size = BODY_SIZE
    r1.font.bold = True
    r1.font.color.rgb = RGBColor(0x37, 0x5E, 0x23)
    for q in questions:
        pq = cell.add_paragraph(f"• {q}")
        for r in pq.runs:
            r.font.name = FONT_NAME
            r.font.size = BODY_SIZE
    doc.add_paragraph()

def key_term(doc, term, definition, ref_num=None):
    """Bolded key term + definition on same paragraph."""
    para = doc.add_paragraph()
    rt = para.add_run(f"{term}: ")
    rt.font.name  = FONT_NAME
    rt.font.size  = BODY_SIZE
    rt.font.bold  = True
    rt.font.color.rgb = CLR_MID_BLUE
    rd = para.add_run(definition)
    rd.font.name = FONT_NAME
    rd.font.size = BODY_SIZE
    if ref_num:
        rc = para.add_run(f" [{ref_num}]")
        rc.font.name  = FONT_NAME
        rc.font.size  = Pt(8)
        rc.font.color.rgb = CLR_MID_BLUE
        rc.font.bold  = True
    para.paragraph_format.space_after = Pt(4)
    return para

def divider(doc):
    doc.add_paragraph("─" * 80)

def self_check(doc, questions):
    h3(doc, "Self-Check Questions")
    for i, q in enumerate(questions, 1):
        para = doc.add_paragraph()
        rn = para.add_run(f"{i}. ")
        rn.font.name = FONT_NAME
        rn.font.size = BODY_SIZE
        rn.font.bold = True
        rq = para.add_run(q)
        rq.font.name = FONT_NAME
        rq.font.size = BODY_SIZE

def add_reference_list(doc):
    doc.add_page_break()
    h1(doc, "References")
    body(doc, "All references cited inline throughout the text using [N] notation.")
    doc.add_paragraph()
    for num in sorted(REFERENCES.keys()):
        para = doc.add_paragraph()
        rn = para.add_run(f"[{num}]  ")
        rn.font.name  = FONT_NAME
        rn.font.size  = BODY_SIZE
        rn.font.bold  = True
        rn.font.color.rgb = CLR_MID_BLUE
        rt = para.add_run(REFERENCES[num])
        rt.font.name = FONT_NAME
        rt.font.size = BODY_SIZE
        para.paragraph_format.left_indent = Inches(0.4)
        para.paragraph_format.first_line_indent = Inches(-0.4)
        para.paragraph_format.space_after = Pt(5)


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER CONTENT
# ─────────────────────────────────────────────────────────────────────────────

def chapter_01(doc):
    h1(doc, "Chapter 1: Identity Foundations")
    cite(doc,
         "Identity and Access Management (IAM) is the discipline of ensuring that the right principals have the right access to the right resources at the right time. It sits at the intersection of security, compliance, and user experience — a discipline that failures in can either lock out legitimate users or allow attackers unfettered access to crown-jewel systems.",
         [1, 17])

    h2(doc, "1.1  What Is an Identity?")
    analogy_box(doc,
        "The Hotel Key Card",
        "Think of an identity as a hotel key card. The card itself is just plastic — it has no meaning without the hotel's system behind it. The system knows: which room you booked, how long your stay is, and whether you've checked in yet. Identity is the claim; the identity system is what gives that claim meaning and enforces what it can unlock.")
    cite(doc,
         "In digital systems, an identity is an authoritative representation of a principal — a user, device, application, or service. Every identity consists of a set of attributes (name, department, role, security clearance) and is anchored to an authoritative source such as an HR system or a directory service.",
         [1])
    key_term(doc, "Principal", "Any entity (human, machine, or service) that can authenticate and be granted access.", 1)
    key_term(doc, "Identity Provider (IdP)", "A system that creates, maintains, and manages identity information while providing authentication services to relying applications.", 1)
    key_term(doc, "Service Provider (SP) / Relying Party (RP)", "An application or service that trusts the IdP to assert who the user is, without performing authentication itself.", 5)

    h2(doc, "1.2  The Identity Lifecycle")
    analogy_box(doc,
        "The Employee Badge",
        "An identity lifecycle is like an employee badge: created on day one (Joiner), updated when the employee changes departments (Mover), and deactivated the moment they leave (Leaver). A badge still active after someone leaves is exactly the same risk as a user account left enabled after termination.")
    cite(doc,
         "The Joiner-Mover-Leaver (JML) lifecycle defines the three critical events that drive identity changes. Joiner: new employee or contractor is onboarded — accounts provisioned within hours of HR trigger. Mover: role change, department transfer, or privilege change — entitlements adjusted to reflect new position. Leaver: termination or contract end — all access revoked within SLA (typically 4 hours for full-time employees, 1 hour for privileged accounts).",
         [17, 18])
    bullet(doc, "Joiner: Account creation, group membership, system access provisioned via IGA workflow")
    bullet(doc, "Mover: Role-based entitlement change; old access removed before new access granted (no accumulation)")
    bullet(doc, "Leaver: Disable account, remove group memberships, revoke tokens, archive data, notify manager")

    h2(doc, "1.3  Authentication vs. Authorisation")
    analogy_box(doc,
        "The Airport Security Lane",
        "Authentication is the passport control desk — it asks 'Who are you?' and verifies your identity document. Authorisation is the boarding gate — it asks 'Are you allowed on this flight?' You can pass passport control (authenticate) and still be denied boarding (not authorised) because you're on the wrong flight.")
    key_term(doc, "Authentication (AuthN)", "The process of verifying that a claimed identity is genuine. Factors: something you know (password), something you have (hardware token), something you are (biometric).", 1)
    key_term(doc, "Authorisation (AuthZ)", "The process of determining what an authenticated principal is permitted to do. Separate from authentication — a user may authenticate successfully but have no authorisation to a specific resource.", 1)
    key_term(doc, "Multi-Factor Authentication (MFA)", "Authentication using two or more independent factors from different categories. Phishing-resistant MFA (FIDO2/passkeys, PIV/smart card) is the gold standard.", 1)

    h2(doc, "1.4  Access Control Models")
    cite(doc,
         "Four primary access control models exist, each with different trade-offs between flexibility and administrative overhead.",
         [17])
    bullet(doc, "DAC (Discretionary Access Control): Resource owner decides who gets access. Simple but unscalable — file shares with individual ACLs are DAC.")
    bullet(doc, "MAC (Mandatory Access Control): Labels govern access — a Top Secret user cannot share with a Confidential user. Used in government/military (SELinux, MLS).")
    bullet(doc, "RBAC (Role-Based Access Control): Access granted based on job role (e.g., 'Nurse' role = EHR read access). Most common enterprise model. Risk: role explosion and birthright access accumulation.")
    bullet(doc, "ABAC (Attribute-Based Access Control): Access granted based on policy evaluating multiple attributes — user.department == resource.owner_department AND time.hour BETWEEN 8 AND 18. Most flexible; used in Zero Trust environments.")

    note_box(doc, "Architect Insight",
             "RBAC is where most organisations start. ABAC is where mature Zero Trust organisations end up. The migration path is: start with RBAC to bring order, then layer ABAC policies on top for context-aware control without rebuilding the RBAC foundation.")

    self_check(doc, [
        "Explain the difference between authentication and authorisation using a real-world analogy of your own.",
        "A user changes departments from Finance to Engineering. List every JML action that should be triggered and in what order.",
        "Which access control model would you recommend for a clinical EHR system? Justify your choice with at least two specific requirements.",
        "What is the difference between a principal and an identity? Give three examples of non-human principals.",
        "Why is phishing-resistant MFA categorically different from SMS-based MFA?"
    ])
    interview_box(doc, [
        "What is the difference between RBAC and ABAC, and when would you choose one over the other?",
        "Walk me through the Leaver process: what must happen in the first 4 hours after a termination?",
        "Why is MFA coverage a lagging indicator rather than a leading indicator of identity security maturity?",
        "How does a Zero Trust model change the role of network perimeter in an access control architecture?"
    ])
    doc.add_page_break()


def chapter_02(doc):
    h1(doc, "Chapter 2: Directory Services")
    cite(doc,
         "Directory services are the authoritative source of identity truth in enterprise environments. Active Directory Domain Services (AD DS) remains the dominant on-premises directory technology, serving as the backbone for authentication, authorisation, and policy enforcement across hundreds of millions of endpoints worldwide.",
         [15])

    h2(doc, "2.1  Active Directory Architecture")
    analogy_box(doc,
        "The Corporate Org Chart",
        "Active Directory is structured like a corporate org chart. A Forest is the company — it sets the ultimate trust boundary. Domains are divisions within the company. Organisational Units (OUs) are departments. Users and computers are individuals sitting in those departments. Group Policy Objects (GPOs) are the company policies posted on the walls — they apply to whoever sits in that office, whether they like it or not.")
    cite(doc,
         "Active Directory uses a hierarchical namespace. A Forest is the top-level security boundary containing one or more Domains sharing a common schema and Global Catalog. Domains contain Organisational Units (OUs) which contain Users, Groups, Computers, and other OUs. Trust relationships between domains allow authentication to flow across the hierarchy.",
         [15])
    key_term(doc, "Forest", "The ultimate security boundary in Active Directory. Separate forests do not share schema, configuration, or trust by default.", 15)
    key_term(doc, "Domain", "An administrative boundary within a forest. Domains share the forest schema but have independent domain-level policies and their own domain controllers.", 15)
    key_term(doc, "Global Catalog (GC)", "A domain controller that holds a partial read-only replica of all objects in the forest. Required for forest-wide user lookups and UPN-based logon.", 15)

    h2(doc, "2.2  FSMO Roles")
    cite(doc,
         "Flexible Single Master Operations (FSMO) roles are Active Directory functions that can only be performed by one DC at a time to prevent conflicting writes. There are five FSMO roles across two categories.",
         [15])
    bullet(doc, "Schema Master (forest-wide): Controls all schema modifications. Only one per forest.")
    bullet(doc, "Domain Naming Master (forest-wide): Controls addition/removal of domains. Only one per forest.")
    bullet(doc, "PDC Emulator (per domain): Handles password changes, time synchronisation, Group Policy updates, and account lockouts.")
    bullet(doc, "RID Master (per domain): Allocates pools of Relative Identifiers (RIDs) to domain controllers for creating security principals.")
    bullet(doc, "Infrastructure Master (per domain): Maintains references to objects in other domains.")
    note_box(doc, "Architecture Pitfall",
             "Infrastructure Master must NOT be co-located with a Global Catalog server in a multi-domain forest. Because GC holds all objects, the Infrastructure Master never sees phantom objects that need updating — causing stale cross-domain references. In single-domain forests, this restriction does not apply.")

    h2(doc, "2.3  Kerberos Authentication Protocol")
    analogy_box(doc,
        "The Concert Wristband System",
        "Kerberos works like a concert with multiple stages: (1) You show your ID at the main gate and get a wristband (TGT — Ticket Granting Ticket). (2) At each stage, you show your wristband and get a single-use stage pass (Service Ticket — ST). (3) Each stage only accepts its own passes — they never see your original ID. The wristband desk (KDC) is the trust anchor; the stages (services) never need to call back to verify you.")
    cite(doc,
         "Kerberos v5 [RFC 4120] is the default authentication protocol in Active Directory environments. The three-party exchange: (1) AS-REQ/AS-REP: Client requests TGT from Authentication Service, encrypted with krbtgt hash. (2) TGS-REQ/TGS-REP: Client presents TGT to Ticket Granting Service, requests Service Ticket for specific resource. (3) AP-REQ: Client presents Service Ticket to the target service, which decrypts it with its own secret key.",
         [15])

    h2(doc, "2.4  Kerberos Attack Surface")
    cite(doc,
         "Three major attack categories target Kerberos. Each exploits a different design assumption of the protocol.",
         [12, 15])
    key_term(doc, "Kerberoasting", "Requests Service Tickets for user accounts with SPNs (Service Principal Names). The ticket is encrypted with the service account's NTLM hash — offline crackable. Mitigation: Use Managed Service Accounts (gMSA) with 240-character random passwords.", 12)
    key_term(doc, "AS-REP Roasting", "Targets accounts with Pre-Authentication disabled (DoesNotRequirePreAuth). The KDC returns an AS-REP encrypted with the user's password hash without verifying identity first. Mitigation: Never disable pre-authentication.", 12)
    key_term(doc, "Pass-the-Ticket (PtT)", "Extracts Kerberos tickets from memory (lsass.exe) and reuses them on another machine. Mitigation: Credential Guard, Protected Users group, Restricted Admin mode.", 12)

    h2(doc, "2.5  Group Policy Objects")
    analogy_box(doc,
        "The Building Code",
        "Group Policy is like a city's building code. The city code (domain policy) applies everywhere. Borough codes (OU policies) add local requirements. An individual building owner can post their own rules (local policy) — but city code always wins. The processing order — Local → Site → Domain → OU (LSDOU) — determines which rule wins on conflict.")
    cite(doc,
         "GPO processing follows the LSDOU order: Local Policy → Site GPOs → Domain GPOs → OU GPOs (parent to child, innermost OU wins). Block Inheritance prevents parent GPOs from applying to a specific OU. Enforced (No Override) GPOs bypass Block Inheritance.",
         [17])

    self_check(doc, [
        "Draw the Kerberos AS-REQ, TGS-REQ, and AP-REQ flow between Client, KDC, and File Server.",
        "Why must the Infrastructure Master not be on a GC server in a multi-domain forest?",
        "Explain the difference between Kerberoasting and AS-REP Roasting, and give a mitigation for each.",
        "What does the LSDOU acronym stand for, and which setting can override LSDOU processing order?",
        "What is a Golden Ticket attack, and why does rotating the krbtgt key TWICE matter?"
    ])
    interview_box(doc, [
        "A penetration tester finds 23 accounts with SPNs in your domain. What is the risk, and what is your remediation plan?",
        "Explain what krbtgt is and why it matters for Golden Ticket attacks.",
        "You're asked to merge two AD forests from an acquisition. Walk me through the key architectural decisions.",
        "How does Password Hash Sync (PHS) work, and why might you choose it over AD FS?"
    ])
    doc.add_page_break()


def chapter_03(doc):
    h1(doc, "Chapter 3: Public Key Infrastructure")
    cite(doc,
         "Public Key Infrastructure (PKI) is the framework that makes secure digital communication possible. It solves the fundamental problem of distributed trust: how do two parties who have never met verify each other's identity and communicate securely? The answer is a chain of trust anchored in a Certificate Authority.",
         [22])

    h2(doc, "3.1  PKI Fundamentals")
    analogy_box(doc,
        "The Notary Chain",
        "A PKI certificate chain works like a chain of notarised documents. Your driver's licence (leaf certificate) was issued by the DMV (Intermediate CA), which is authorised by the state government (Root CA). If you trust the state, you trust the DMV, and therefore trust the licence. Break any link in that chain — the state gets compromised, or the DMV's seal is forged — and every licence it ever issued becomes suspect.")
    cite(doc,
         "Public key cryptography uses asymmetric key pairs: a public key (shareable) and a private key (secret). A digital certificate (X.509 format) binds a public key to an identity, signed by a CA whose own certificate is trusted by the verifier. The chain: Root CA → Intermediate/Issuing CA → Leaf Certificate.",
         [22])
    key_term(doc, "Certificate Authority (CA)", "An entity trusted to issue, sign, and revoke digital certificates. The Root CA's public key is pre-trusted by operating systems and browsers.", 22)
    key_term(doc, "X.509 Certificate", "The standard format for public key certificates. Contains: subject, issuer, validity period, public key, Subject Alternative Names (SANs), and digital signature.", 22)
    key_term(doc, "Certificate Revocation List (CRL)", "A periodically published list of revoked certificate serial numbers. Checked by clients during certificate validation. OCSP is the online real-time alternative.", 22)

    h2(doc, "3.2  PKI Hierarchy Design")
    cite(doc,
         "Two-tier PKI (Root CA → Issuing CA) is appropriate for most enterprise environments. Three-tier (Root → Policy CA → Issuing CA) adds a layer of separation for very large, multi-region deployments. The Root CA should be offline (air-gapped) — it issues only the Issuing CA certificate and then powers off.",
         [22])
    note_box(doc, "Architecture Best Practice",
             "Offline Root CA: Store the Root CA on an air-gapped machine in a physically secured location (HSM + safe). Boot it only to issue new Issuing CA certificates (typically every 5-10 years) or to update the CRL. The Root CA's compromise means every certificate in the hierarchy must be replaced.")

    h2(doc, "3.3  ADCS ESC Vulnerabilities")
    cite(doc,
         "Active Directory Certificate Services (ADCS) misconfigurations create a category of privilege escalation attacks catalogued as ESC1 through ESC8. These were detailed in the 'Certified Pre-Owned' research by SpecterOps.",
         [11])
    key_term(doc, "ESC1", "Certificate template allows enrollee to supply Subject Alternative Name (SAN) + Client Auth EKU + wide enrollment rights. Attacker can request certificate for any user including Domain Admin.", 11)
    key_term(doc, "ESC2", "Certificate template has 'Any Purpose' EKU — can be used for any purpose including client authentication.", 11)
    key_term(doc, "ESC3", "Certificate template has Certificate Request Agent EKU — allows enrolling on behalf of another user.", 11)
    key_term(doc, "ESC8", "ADCS web enrollment (certsrv) accessible over HTTP. NTLM relay attack allows coercing a machine to authenticate and relaying that credential to ADCS to request a certificate.", 11)
    analogy_box(doc,
        "The Rubber Stamp Office",
        "ESC1 is like a rubber stamp office that lets you write whatever name you want on the form before they stamp it. You walk in claiming to be 'Domain Administrator', they stamp your certificate, and suddenly every door in the building opens for you.")

    h2(doc, "3.4  Certificate Revocation")
    cite(doc,
         "Two revocation mechanisms exist: CRL (batch, published periodically) and OCSP (Online Certificate Status Protocol — real-time per-certificate query). OCSP Stapling improves privacy by having the server pre-fetch and cache the OCSP response, including it in the TLS handshake so clients don't need to contact the CA directly.",
         [22])

    self_check(doc, [
        "Explain the certificate chain for a leaf TLS certificate on a public website. Name each certificate in the chain.",
        "Why must the Root CA be kept offline? What is the impact if it is compromised?",
        "Describe the ESC1 attack. What three conditions must be true for it to be exploitable?",
        "What is the difference between CRL and OCSP? When would you choose OCSP Stapling?",
        "What does CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT mean, and why is it dangerous?"
    ])
    interview_box(doc, [
        "Walk me through the ADCS ESC1 attack chain from initial enumeration to Domain Admin.",
        "Your organisation's Root CA certificate expires in 6 months. What is your remediation plan?",
        "What is OCSP Stapling and why does it improve both performance and privacy?",
        "How would you audit your ADCS environment for misconfigured certificate templates?"
    ])
    doc.add_page_break()


def chapter_04(doc):
    h1(doc, "Chapter 4: Federation Protocols — SAML, OAuth 2.0, and OIDC")
    cite(doc,
         "Modern identity federation separates authentication from application logic. Rather than each application maintaining its own credential store, federation delegates authentication to a trusted Identity Provider. Three protocols dominate enterprise federation: SAML 2.0 (XML-based, enterprise SSO), OAuth 2.0 (delegated authorisation framework), and OpenID Connect (OIDC — identity layer on OAuth 2.0).",
         [3, 4, 5, 21])

    h2(doc, "4.1  SAML 2.0")
    analogy_box(doc,
        "The Letter of Introduction",
        "SAML is like a formal letter of introduction. Your employer (IdP) writes a letter saying 'This is Alice, she works in Finance, she has read access.' You carry that letter (SAML Assertion) to the hotel (SP). The hotel doesn't need to call your employer — it trusts the letter because it knows the employer's signature (cryptographic signature).")
    cite(doc,
         "SAML 2.0 (Security Assertion Markup Language) is an XML-based protocol for exchanging authentication and authorisation data between an IdP and SP. The SAML Assertion contains three statement types: AuthnStatement (who authenticated, when, by what method), AttributeStatement (user attributes), and AuthzDecisionStatement (access decision). The Assertion is signed using XML-DSIG with the IdP's private key.",
         [5])
    key_term(doc, "SAML Assertion", "XML document asserting information about a subject. Contains: Issuer, Subject (NameID), Conditions (NotBefore/NotOnOrAfter), AuthnStatement, AttributeStatement, and Signature.", 5)
    key_term(doc, "Service Provider-Initiated (SP-init)", "User accesses SP → SP generates AuthnRequest → redirects to IdP → IdP authenticates → sends Assertion to SP via browser POST/redirect.", 5)
    key_term(doc, "IdP-Initiated SSO", "User starts at IdP portal → selects application → IdP sends unsolicited Assertion to SP. Less secure: no AuthnRequest means no CSRF protection nonce.", 5)

    h2(doc, "4.2  OAuth 2.0")
    analogy_box(doc,
        "The Valet Parking Ticket",
        "OAuth 2.0 is about delegation, not identity. When you give your car to a valet, you hand over a valet key (access token) — not your house key (credentials). The valet can drive the car (access the resource) but can't start your home alarm (scope-limited). You didn't give them your identity — you gave them scoped, time-limited permission.")
    cite(doc,
         "OAuth 2.0 [RFC 6749] is an authorisation framework, not an authentication protocol. It allows a user (Resource Owner) to grant a third-party application (Client) limited access to their data at a Resource Server, without sharing credentials. The Client obtains an Access Token from the Authorisation Server using one of four grant types.",
         [3])
    key_term(doc, "Authorisation Code + PKCE", "Recommended grant for user-facing applications. PKCE (Proof Key for Code Exchange) [RFC 7636] prevents authorisation code interception attacks by binding the code to a cryptographic verifier known only to the initiating client.", 3)
    key_term(doc, "Client Credentials", "Machine-to-machine grant. No user involved. Service authenticates directly to token endpoint using client_id + client_secret (or certificate). Returns access token scoped to the service's permissions.", 3)
    key_term(doc, "Access Token", "A credential representing the authorisation granted to the client. Typically a JWT. Scoped (contains 'scope' claim), time-limited (exp claim), and audience-constrained (aud claim).", 4)

    h2(doc, "4.3  OpenID Connect (OIDC)")
    cite(doc,
         "OpenID Connect [OpenID Foundation, 2014] adds an identity layer on top of OAuth 2.0. OIDC introduces the ID Token — a JWT containing claims about the authenticated user (sub, iss, aud, iat, exp, nonce). The UserInfo endpoint provides additional attributes. OIDC enables SSO while OAuth 2.0 provides API authorisation.",
         [21])
    key_term(doc, "ID Token", "A JWT asserting the user's identity. Must be validated: signature (RS256/ES256), issuer (iss == IdP), audience (aud == client_id), expiry (exp > now), nonce (matches original request).", 21)
    key_term(doc, "sub Claim", "Subject identifier — a stable, unique, opaque identifier for the user within the IdP. Do not use email as subject — it can change.", 21)

    h2(doc, "4.4  JWT Anatomy and Validation")
    analogy_box(doc,
        "The Signed Cheque",
        "A JWT is like a signed cheque: it contains the payee (aud), the amount (scope/claims), the date (iat/exp), and the bank's signature (RS256 signature). Anyone can read the cheque (it's base64-encoded, not encrypted). But only the bank's genuine signature makes it valid. A cheque that's expired (exp in the past) or has been altered (signature mismatch) is worthless.")
    cite(doc,
         "A JWT [RFC 7519] consists of three base64url-encoded parts separated by dots: Header.Payload.Signature. Header specifies the algorithm (alg: RS256) and key ID (kid). Payload contains claims. Signature is computed over Header+Payload using the IdP's private key. NEVER accept 'none' algorithm — this is a well-known attack that skips signature verification entirely.",
         [4])

    self_check(doc, [
        "Draw the SAML SP-initiated SSO flow, naming every message and the direction it travels.",
        "Why is OAuth 2.0 not an authentication protocol? What problem does it actually solve?",
        "List the five validations that must be performed on an ID Token before trusting it.",
        "What is PKCE, and what specific attack does it prevent in the Authorisation Code flow?",
        "What is the 'none algorithm' attack on JWTs, and how do you prevent it?"
    ])
    interview_box(doc, [
        "A developer asks why they should use OIDC instead of SAML for a new SPA. What is your recommendation?",
        "Walk me through the difference between an ID Token and an Access Token.",
        "What claims would you check to validate that a JWT was not tampered with?",
        "Explain the Authorisation Code + PKCE flow from browser to token issuance."
    ])
    doc.add_page_break()


def chapter_05(doc):
    h1(doc, "Chapter 5: Privileged Access Management")
    cite(doc,
         "Privileged Access Management (PAM) is the set of controls, processes, and technologies that govern the use of elevated permissions. Privileged accounts — Domain Admins, root accounts, database administrators, service accounts — represent the highest-value targets for attackers. A compromised privileged account typically means full domain or cloud tenant compromise.",
         [19, 17])

    h2(doc, "5.1  The PAM Problem")
    analogy_box(doc,
        "The Master Key",
        "A privileged account is like the building's master key. In a well-run building, the master key is kept in a locked box, checked out only with a log entry and a reason, checked back in immediately after use, and the lock is changed if it's ever lost. In most enterprises without PAM, the master key is photocopied and hanging on 15 people's lanyards.")
    cite(doc,
         "The Verizon DBIR consistently shows that credential abuse is the #1 initial access vector. Privileged credential abuse is the #1 path to full compromise. The three problems PAM solves: (1) Standing access — privileged accounts that are always active, always exposed. (2) Shared credentials — multiple admins share a single admin password with no accountability. (3) No session accountability — no recording of what was done with privileged access.",
         [19])

    h2(doc, "5.2  CyberArk Architecture")
    cite(doc,
         "CyberArk Privileged Access Security (PAS) is the market-leading PAM platform for enterprise environments. Core components: Digital Vault (encrypted credential store), Central Policy Manager (CPM — automated password rotation), Privileged Session Manager (PSM — session proxy with recording), Application Identity Manager (AIM — eliminates hardcoded credentials in applications).",
         [19])
    key_term(doc, "Digital Vault", "Encrypted credential repository. Credentials never leave the vault in cleartext — PSM injects them directly into sessions without exposing them to the user.", 19)
    key_term(doc, "PSM (Privileged Session Manager)", "Session proxy that brokers connections to target systems. The administrator connects to PSM; PSM connects to the target using the vaulted credential. The admin never sees the password. Sessions are recorded.", 19)
    key_term(doc, "CPM (Central Policy Manager)", "Automated password rotation engine. Rotates passwords on schedule or on-demand. Verifies credentials after rotation. Handles platform-specific rotation (Windows, Linux, Oracle, MSSQL, network devices).", 19)

    h2(doc, "5.3  Azure PIM — Just-in-Time Privileged Access")
    analogy_box(doc,
        "The Surgeon's Scrub-In",
        "Azure PIM is like surgical scrub-in. The surgeon doesn't walk around the hospital with sterile gloves on all day — that would be wasteful and would constantly contaminate the gloves. She scrubs in (activates the role), performs the operation (completes the task), and scrubs out (deactivates). The sterile environment is only maintained for as long as needed.")
    cite(doc,
         "Azure AD Privileged Identity Management (PIM) implements Just-in-Time (JIT) access for Entra ID roles. Users are assigned as 'eligible' rather than 'permanently active'. To use a privileged role, the user activates it — triggering MFA, justification entry, and optionally manager approval. The role is active for a defined window (1-8 hours) then automatically deactivates.",
         [8])
    key_term(doc, "Eligible Assignment", "User can request activation of the role but is not permanently active. Safest configuration for privileged roles.", 8)
    key_term(doc, "Active Assignment", "User is permanently in the role — no activation required. Should be reserved for break-glass accounts or service accounts only.", 8)

    h2(doc, "5.4  Windows LAPS")
    cite(doc,
         "Local Administrator Password Solution (LAPS) manages unique, rotated local administrator passwords for every domain-joined machine. Without LAPS, a common pattern is the same local admin password across all machines — a single credential compromise enables lateral movement to every endpoint. LAPS stores the password in AD (Legacy LAPS: ms-Mcs-AdmPwd; Windows LAPS: msLAPS-Password), protected by ACL.",
         [17])

    h2(doc, "5.5  Break-Glass Accounts")
    analogy_box(doc,
        "The Fire Extinguisher Case",
        "Break-glass accounts are like fire extinguisher cases — they must be immediately accessible in an emergency but sealed under normal conditions. Breaking the glass (using the account) is an immediate alarm. In Azure, break-glass accounts should be: cloud-only (not synced — can't be affected by on-prem outage), FIDO2-only (can't be phished), excluded from CA policies (can always sign in), and monitored so any sign-in triggers a P0 alert.")

    self_check(doc, [
        "What are the three main problems PAM solves? Give a concrete example of each.",
        "Explain the difference between CyberArk's CPM and PSM. When does each activate?",
        "What is the difference between 'eligible' and 'active' PIM assignment? When is 'active' appropriate?",
        "A breach investigation reveals a lateral movement path from a compromised workstation to 40 servers all using the same local admin password. How would LAPS have prevented this?",
        "List the four properties a break-glass account must have and explain why each matters."
    ])
    interview_box(doc, [
        "A vendor VPN account was used in a ransomware attack with a 14-day dwell time. How would CyberArk PSM have changed the outcome?",
        "Walk me through how JIT access works in Azure PIM from the user's perspective and the audit trail it creates.",
        "What is the LAPS attribute in Active Directory, and what ACL should protect it?",
        "How do you design a break-glass account strategy for an Entra ID tenant?"
    ])
    doc.add_page_break()


def chapter_06(doc):
    h1(doc, "Chapter 6: Zero Trust Architecture")
    cite(doc,
         "Zero Trust is an architectural philosophy, not a product. Its core principle: 'Never trust, always verify.' Rather than assuming that anything inside the network perimeter is safe, Zero Trust treats every access request as if it originates from an untrusted network — regardless of source IP address, network segment, or prior authentication.",
         [2, 6])

    h2(doc, "6.1  NIST SP 800-207 Tenets")
    cite(doc,
         "NIST SP 800-207 defines seven tenets of Zero Trust that together eliminate implicit trust from the network model.",
         [2])
    bullet(doc, "All data sources and computing services are resources (including personal devices on corporate networks).")
    bullet(doc, "All communication is secured regardless of network location (TLS everywhere, mTLS for east-west).")
    bullet(doc, "Access to individual enterprise resources is granted per-session (no standing network access).")
    bullet(doc, "Access is determined by dynamic policy including observable state of client identity, application, and requesting asset.")
    bullet(doc, "The enterprise monitors and measures the integrity and security posture of all owned and associated assets.")
    bullet(doc, "All resource authentication and authorisation are dynamic and strictly enforced before access is allowed.")
    bullet(doc, "The enterprise collects as much information as possible about the current state of assets, network infrastructure, and communications.")

    h2(doc, "6.2  CISA Zero Trust Maturity Model")
    analogy_box(doc,
        "The Security Belt System",
        "The CISA ZT Maturity Model works like a martial arts belt system. Traditional (white belt): castle-and-moat, VPN, perimeter trust. Advanced (coloured belt): MFA deployed, some device compliance, identity-based CA policies. Optimal (black belt): every access decision is contextual, continuous, and automated across all five pillars simultaneously.")
    cite(doc,
         "The CISA Zero Trust Maturity Model v2.0 defines five pillars and three maturity stages (Traditional, Advanced, Optimal). The five pillars are: Identity, Device, Network, Application, and Data. Progress in each pillar is independent — an organisation can be Optimal in Identity and Traditional in Data.",
         [6])

    h2(doc, "6.3  Conditional Access — Tiered Model")
    cite(doc,
         "Microsoft's Conditional Access (CA) is the Zero Trust policy engine for Entra ID. A tiered CA policy framework provides defence in depth: no single policy covers all scenarios, and each tier addresses a specific threat class.",
         [8])
    key_term(doc, "Tier B (Baseline)", "Block legacy authentication; require MFA for all users. Non-negotiable minimum. Blocks credential stuffing and password spray that rely on legacy auth protocols (IMAP, POP3, SMTP AUTH).", 8)
    key_term(doc, "Tier I (Identity Protection)", "Sign-in risk ≥ Medium → require MFA; User risk High → require password change. Requires Entra ID P2. Integrates Microsoft's threat intelligence to step up authentication on suspicious signals.", 8)
    key_term(doc, "Tier D (Device)", "Require Intune-compliant device for sensitive applications; session controls for unmanaged devices. BYOD scenario: allow access via browser with limited download/print capability.", 8)
    key_term(doc, "Tier P (Privileged)", "Admin roles require phishing-resistant MFA (FIDO2/smart card) + PAW location requirement. Prevents credential phishing from affecting privileged accounts.", 8)

    h2(doc, "6.4  Continuous Access Evaluation (CAE)")
    analogy_box(doc,
        "The Library Book Scanner",
        "Traditional token-based auth is like borrowing a library book on Monday — you can keep it until the due date (token expiry) regardless of what happens at the library. CAE is like the library installing a continuous-scan system: if the book is reported stolen (account disabled), or the library changes policy (risk level changes), your access is revoked mid-loan rather than waiting for renewal.")
    cite(doc,
         "CAE extends token lifetime to up to 28 hours (vs. the traditional 60-90 minutes) while enabling near-real-time revocation. CAE-capable resources (Exchange Online, SharePoint, Teams) maintain a long-lived session, but if the IdP signals a critical event (password change, account disable, location change, risk elevation), the resource rejects the current token within seconds via HTTP 401 claims challenge.",
         [20])

    self_check(doc, [
        "State the Zero Trust principle in one sentence and explain what 'implicit trust' means in a traditional perimeter model.",
        "Name the five CISA Zero Trust pillars and give one control per pillar at the Optimal maturity level.",
        "What is the difference between a Tier B and Tier I Conditional Access policy?",
        "How does CAE differ from traditional token-based authentication? What is the maximum token lifetime under CAE?",
        "A user's account is disabled at 9:00 AM. With CAE enabled, when will their Outlook session stop working?"
    ])
    interview_box(doc, [
        "Your CISO asks: 'We just deployed MFA — are we Zero Trust now?' How do you respond?",
        "What is Continuous Access Evaluation, and how does it change incident response for a compromised account?",
        "Walk me through the tiered Conditional Access model you would deploy for a 10,000-user enterprise.",
        "How does Zero Trust change the value of network segmentation?"
    ])
    doc.add_page_break()


def chapter_07(doc):
    h1(doc, "Chapter 7: Identity Governance and Administration")
    cite(doc,
         "Identity Governance and Administration (IGA) is the discipline of managing the full identity lifecycle — who has access to what, for how long, and whether that access is still appropriate. IGA transforms identity management from a reactive IT function into a proactive, auditable governance programme.",
         [18, 17])

    h2(doc, "7.1  IGA vs. IAM")
    analogy_box(doc,
        "The Staffing Agency vs. The Security Guard",
        "IAM is the security guard at the door — it authenticates and enforces access in real time. IGA is the staffing agency that decided who should be allowed in the building, reviewed those decisions quarterly, and revokes the badge when the contract ends. Without IGA, IAM is enforcing decisions that were never reviewed — a guard following a guest list that was written three years ago and never updated.")
    cite(doc,
         "IAM enforces access; IGA governs it. IGA capabilities: provisioning/deprovisioning automation (JML), access request and approval workflows, Segregation of Duties (SoD) policy enforcement, role management (role mining, RBAC), access certification campaigns, and audit evidence generation for SOX/HIPAA/PCI compliance.",
         [18])

    h2(doc, "7.2  JML Automation and SLAs")
    cite(doc,
         "JML (Joiner-Mover-Leaver) automation is the primary business value of IGA. Key SLAs: Joiner access fully provisioned ≤ 2 hours from HR trigger. Mover entitlement change ≤ 4 hours from HR role change. Leaver all access revoked ≤ 4 hours from HR termination event (privileged access ≤ 1 hour).",
         [18, 25])

    h2(doc, "7.3  Segregation of Duties (SoD)")
    analogy_box(doc,
        "The Four-Eyes Principle",
        "SoD is the four-eyes principle applied to entitlements. In financial controls, the person who creates a vendor (AP-Create-Vendor) cannot also approve payments to that vendor (AP-Approve-Payment) — because they could create a fictitious vendor and pay themselves. SoD matrix: every pair of roles that, if held simultaneously, creates a fraud or error risk.")
    cite(doc,
         "SoD defines role pairs that must not be held by the same person. Critical SoD conflicts require immediate remediation (no compensating control acceptable). High SoD conflicts can be mitigated with enhanced monitoring and quarterly review. SoD violations are a primary audit finding for SOX ITGC access controls.",
         [18, 25])

    h2(doc, "7.4  SCIM 2.0 Protocol")
    cite(doc,
         "System for Cross-domain Identity Management (SCIM) 2.0 [RFC 7644] is the standard protocol for automating user provisioning between identity systems and SaaS applications. SCIM defines REST API endpoints (/Users, /Groups), JSON schema (core attributes + extensions), and operations (POST Create, GET Read, PATCH Update, DELETE).",
         [13])
    key_term(doc, "externalId", "The IGA system's internal ID for the user, stored in the SaaS application. Used to find the correct user record during subsequent sync operations. Must round-trip correctly through SCIM.", 13)
    key_term(doc, "SCIM Provisioning vs. SSO", "SCIM handles account lifecycle (create/update/delete). SSO handles authentication. Both are needed: SCIM provisions the account; SSO lets the user log in. They are complementary, not interchangeable.", 13)

    h2(doc, "7.5  Access Certification")
    cite(doc,
         "Access certification (also called access review or access recertification) is a periodic process where managers or data owners review and certify that users still need their current access. Regulatory requirements: SOX ITGC requires at least annual certification of privileged access. HIPAA requires periodic review of access to PHI systems. PCI DSS requires quarterly review of access to cardholder data environments.",
         [24, 25])

    self_check(doc, [
        "What is the difference between IGA and IAM? Give an example of where each is operating.",
        "A terminated employee still has access 6 hours after termination. Which SLA was breached, and what is the first investigation step?",
        "Define Segregation of Duties. Give two examples of SoD conflicts from finance and healthcare.",
        "What HTTP methods does SCIM 2.0 use for Create, Read, Update, and Delete?",
        "What is the difference between a certification campaign and an access request workflow?"
    ])
    interview_box(doc, [
        "Walk me through the automated Leaver process from HR termination event to full access revocation.",
        "How does SoD conflict detection work in a large enterprise with 400 applications and 85,000 users?",
        "What is SCIM, and why is externalId round-trip important?",
        "How would you measure the effectiveness of an access certification programme?"
    ])
    doc.add_page_break()


def chapter_08(doc):
    h1(doc, "Chapter 8: Microsoft Entra ID — Cloud Identity")
    cite(doc,
         "Microsoft Entra ID (formerly Azure Active Directory) is the cloud identity platform serving over 400 million users. It is the primary identity control plane for Microsoft 365, Azure, and thousands of federated SaaS applications. For most enterprise IAM architects, Entra ID is the hub through which all modern identity flows.",
         [8, 16])

    h2(doc, "8.1  Hybrid Identity — PHS vs. AD FS")
    analogy_box(doc,
        "The Phone Line vs. The Relay Station",
        "PHS (Password Hash Sync) is like a phone line directly to the cloud — even if your office building burns down (on-prem AD goes offline), calls still go through because the number was already ported. AD FS is a relay station in your office: if the station goes down, no calls get through. Every WAN outage, every AD FS server patch, is a cloud authentication outage.")
    cite(doc,
         "Three hybrid authentication models: PHS (Password Hash Sync) — Entra Connect syncs password hashes to cloud; authentication happens in Entra ID, not on-prem. PTA (Pass-Through Authentication) — authentication happens on-prem via agent, but cloud directs traffic. AD FS — full on-prem federation server; cloud redirect to on-prem for every authentication. PHS is the recommended model for resilience: on-prem outage does not affect cloud authentication.",
         [16])
    key_term(doc, "Entra Connect", "The synchronisation engine that replicates on-prem AD objects to Entra ID. Manages directory sync, password hash sync, and attribute mapping. The MSOL_ service account it creates is a Tier 0 asset.", 8)
    key_term(doc, "Seamless SSO", "Automatically signs users in when they're on corporate network. Uses Kerberos AZUREADSSO computer account ticket to authenticate to Entra ID without password prompt.", 8)

    h2(doc, "8.2  App Registrations vs. Enterprise Applications")
    analogy_box(doc,
        "The Blueprint vs. The Building",
        "An App Registration is the blueprint — it defines the application identity, permissions it needs, and redirect URIs. The Enterprise Application (Service Principal) is the actual building constructed from that blueprint in your tenant. Multi-tenant apps have one App Registration (in the developer's tenant) and many Enterprise Apps (one per customer tenant).")
    cite(doc,
         "App Registration: defines the application's identity in the developer's home tenant. Contains client secrets, certificates, API permissions, and redirect URIs. Enterprise Application (Service Principal): the instantiation of an App Registration in a specific tenant. Controls user assignment, SSO configuration, and provisioning settings for that tenant.",
         [8])

    h2(doc, "8.3  Managed Identity")
    cite(doc,
         "Managed Identities eliminate the need for application developers to manage credentials. An Azure resource (VM, App Service, Function) is assigned a system-managed or user-managed identity backed by a service principal in Entra ID. The resource can then obtain tokens from the Instance Metadata Service (IMDS) at 169.254.169.254 without any credentials stored in code or configuration.",
         [8])
    note_box(doc, "Security Principle",
             "Managed Identity is the correct pattern for any Azure workload accessing another Azure service (Storage, Key Vault, SQL). If you see a connection string with a password in application config, that is a finding. Replace with Managed Identity token acquisition.")

    h2(doc, "8.4  Microsoft Graph API")
    cite(doc,
         "Microsoft Graph is the unified REST API surface for all Microsoft 365 and Entra ID data. Identity operations: user lifecycle management, group management, sign-in logs, audit logs, Conditional Access policies, risk events. Graph supports delta queries — after an initial full sync, subsequent queries return only objects changed since the last delta link, enabling efficient incremental synchronisation.",
         [8])

    self_check(doc, [
        "Why is PHS recommended over AD FS for hybrid identity resilience? What specific failure scenario does it address?",
        "What is the difference between an App Registration and an Enterprise Application (Service Principal)?",
        "What is the Tier 0 risk associated with the Entra Connect MSOL_ account?",
        "How does a Managed Identity obtain an access token? What endpoint does it use?",
        "What is a Graph delta query, and why is it more efficient than a full sync?"
    ])
    interview_box(doc, [
        "A developer has hardcoded a client secret in their application to access Azure Storage. How do you remediate this?",
        "Walk me through the App Registration audit findings you would look for in a security review.",
        "Explain PHS vs. PTA vs. AD FS and when you would choose each.",
        "How would you detect a compromised Entra Connect sync account using Sentinel?"
    ])
    doc.add_page_break()


def chapter_09(doc):
    h1(doc, "Chapter 9: Auth0 CIAM Platform")
    cite(doc,
         "Customer Identity and Access Management (CIAM) addresses the unique requirements of consumer-facing applications: massive scale (millions of users), social login, frictionless UX, and progressive profiling. Auth0 (now part of Okta) is the leading developer-centric CIAM platform, widely adopted for its extensibility via Actions and its B2B multi-tenancy via Organizations.",
         [9])

    h2(doc, "9.1  Auth0 Tenant Architecture")
    analogy_box(doc,
        "The Apartment Building",
        "An Auth0 tenant is like an apartment building. The building has shared infrastructure (plumbing, elevator, security desk) that all apartments use. Each apartment (application) has its own décor, rules, and entry code. The security desk (Universal Login) is what everyone sees — but the building manager can customise it per floor if needed.")
    cite(doc,
         "An Auth0 tenant is the top-level container for all identity configuration. One tenant per environment (dev/staging/prod) is the recommended pattern. Within a tenant: Applications (clients — SPA, Regular Web App, Native, M2M), APIs (resource servers defining scopes), Connections (user stores — database, social, enterprise, passwordless), and Actions (serverless extensibility pipeline).",
         [9])

    h2(doc, "9.2  Universal Login — Classic vs. New")
    cite(doc,
         "Auth0 Universal Login is the hosted login page that handles authentication flows. New Universal Login (recommended): React-based, supports all Auth0 features including Passkeys, Device Flow, and MFA. Classic Universal Login (deprecated path): Customisable HTML templates with Lock.js widget. Auth0 strongly recommends migrating to New Universal Login for all new implementations.",
         [9])

    h2(doc, "9.3  Auth0 Actions Pipeline")
    analogy_box(doc,
        "The Airport Security Checkpoint",
        "Auth0 Actions are like a sequence of airport security checkpoints. Each checkpoint (Action) can inspect your passport (user profile and login context), add a stamp (custom claim), redirect you to a different queue (MFA challenge), or deny entry (block the login). You pass through each checkpoint in order, and each checkpoint's decision affects the next.")
    cite(doc,
         "Auth0 Actions are serverless Node.js functions that execute at specific points in the auth pipeline. Post-Login Actions are the most common: they can set custom claims on ID tokens and access tokens, enforce MFA based on context, log to external systems, and enrich profiles from external APIs. Actions replaced the deprecated Rules and Hooks system.",
         [9])
    key_term(doc, "Custom Claims Namespacing", "Auth0 requires custom claims in ID/access tokens to use a URI namespace (e.g., https://yourapp.com/department). This prevents collision with OIDC standard claims and ensures spec compliance.", 9)

    h2(doc, "9.4  Organizations (B2B Multi-Tenancy)")
    cite(doc,
         "Auth0 Organizations provides native B2B multi-tenancy. Each Organization represents a customer tenant with its own branding, connections, and member roles. The org_id claim in the access token scopes API requests to the correct tenant. SECURITY CRITICAL: Always validate org_id server-side on the API — never trust client-provided tenant context.",
         [9])

    h2(doc, "9.5  Lazy Migration Pattern")
    analogy_box(doc,
        "The Hotel Key Card Update",
        "Lazy migration is like upgrading hotel key cards without telling guests to come to the desk. The old card (legacy credential in the old system) still works until you actively use it — then the system transparently upgrades it to the new format (migrates to Auth0) and you never notice. Users who never return never need to be migrated at all.")
    cite(doc,
         "Lazy (progressive) migration moves users from a legacy credential store to Auth0 on first login, without requiring a big-bang migration or forced password reset. Auth0 Custom Database connection: Login script checks Auth0 DB first; if not found, falls back to legacy DB; on successful legacy auth, migrates user to Auth0. Import Users mode: once migrated, Auth0 is authoritative and legacy DB is no longer consulted.",
         [9])

    self_check(doc, [
        "What is the difference between Auth0 Rules (deprecated) and Actions? What are the three pipeline trigger points?",
        "Why must custom JWT claims use a namespaced URI? What problem does this solve?",
        "Explain the lazy migration pattern. What happens to users who never return to the application?",
        "What is the org_id claim, and why is server-side validation of it critical?",
        "What is the M2M Client Credentials flow, and why is token caching important?"
    ])
    interview_box(doc, [
        "A company is migrating 3.8 million patient portal accounts from a PHP application to Auth0. Walk me through the migration strategy.",
        "How would you implement adaptive MFA in Auth0 that triggers based on the user's country?",
        "What is the Auth0 Organizations feature, and how does it enable B2B SaaS multi-tenancy?",
        "Why does Auth0 charge per M2M token, and how does token caching address this?"
    ])
    doc.add_page_break()


def chapter_10(doc):
    h1(doc, "Chapter 10: Zero Trust Implementation with Microsoft Defender XDR")
    cite(doc,
         "Microsoft Defender XDR (Extended Detection and Response) integrates Defender for Identity (on-prem AD), Defender for Endpoint (devices), Defender for Office 365 (email), Microsoft Sentinel (SIEM), and Entra ID Protection (cloud identity risk) into a unified security operations platform. The XDR model correlates signals across the kill chain to detect and respond to attacks that span identity, endpoint, and network.",
         [8, 30])

    h2(doc, "10.1  Entra ID Protection")
    analogy_box(doc,
        "The Credit Card Fraud Department",
        "Entra ID Protection works like a credit card fraud department. Every transaction (sign-in) is scored in real time against a model trained on billions of transactions. Unusual location at 3 AM? Flagged. Known botnet IP? Blocked. You don't see most of this — only when the score crosses a threshold does the system intervene, just like your credit card gets declined when the fraud score spikes.")
    cite(doc,
         "Entra ID Protection uses machine learning trained on Microsoft's global threat intelligence to score sign-in risk (per-session) and user risk (aggregate account risk). Sign-in risk detections: unfamiliar sign-in properties, anonymous IP, malware-linked IP, impossible travel, password spray. User risk detections: leaked credentials, suspicious activity patterns.",
         [8])
    key_term(doc, "Sign-in Risk", "Risk score for a specific authentication event. Calculated in real time at token issuance. Triggers Conditional Access 'Tier I' policies to step up authentication or block.", 8)
    key_term(doc, "User Risk", "Aggregate risk score for an account based on all sign-in activity and detected anomalies. A High-risk user should be forced to change password and reset MFA.", 8)

    h2(doc, "10.2  Microsoft Defender for Identity (MDI)")
    cite(doc,
         "Microsoft Defender for Identity deploys lightweight sensors on domain controllers to monitor on-premises AD traffic. MDI detects identity-based attacks in real time: Kerberoasting (bulk TGS-REQ with RC4 encryption), DCSync (unauthorised replication requests), Pass-the-Hash, Golden Ticket, and reconnaissance (LDAP enumeration). MDI alerts integrate directly into Defender XDR incidents.",
         [8, 12])

    h2(doc, "10.3  Microsoft Sentinel KQL Analytics")
    cite(doc,
         "Microsoft Sentinel is a cloud-native SIEM/SOAR platform built on Azure Log Analytics. Analytics rules use KQL (Kusto Query Language) to detect threats across SigninLogs, AuditLogs, SecurityEvent, and other data sources. Key rule categories: impossible travel (geographically inconsistent sign-ins), mass modification (bulk user changes), privileged role assignment, DCSync detection.",
         [30])
    note_box(doc, "KQL Pattern — Impossible Travel",
             "SigninLogs | where TimeGenerated > ago(1h) | where ResultType == 0 | extend Country = tostring(LocationDetails.countryOrRegion) | summarize Countries = make_set(Country), Count = count() by UserPrincipalName | where array_length(Countries) > 1")

    h2(doc, "10.4  Attack Disruption — Autonomous Response")
    cite(doc,
         "Defender XDR Attack Disruption is an autonomous incident response capability that can contain attacks in progress without waiting for analyst intervention. For BEC (Business Email Compromise) and ransomware scenarios: automatically disables compromised user accounts, blocks malicious IP addresses, and isolates compromised devices — all within seconds of detection, dramatically reducing dwell time.",
         [8])

    self_check(doc, [
        "What is the difference between Sign-in Risk and User Risk in Entra ID Protection?",
        "What protocol does MDI monitor on domain controllers, and what specific attack does Event 4769 RC4 indicate?",
        "What is Attack Disruption, and how does it differ from a traditional SOC response workflow?",
        "Write a KQL query that detects when more than 5 Service Ticket requests with RC4 encryption come from the same IP in 15 minutes.",
        "What is MTTD and MTTR, and what are realistic Zero Trust target values?"
    ])
    interview_box(doc, [
        "How does Microsoft Defender XDR correlate signals across identity, endpoint, and email to detect BEC?",
        "Walk me through the Sentinel KQL rule you would write to detect DCSync attacks.",
        "A user's account shows High sign-in risk. Walk me through the automated Conditional Access response and manual investigation steps.",
        "What is the value of CAE from an incident response perspective when a credential is compromised?"
    ])
    doc.add_page_break()


def chapter_11(doc):
    h1(doc, "Chapter 11: Capstone — Vertex Health Systems Architecture")
    cite(doc,
         "This capstone chapter presents a complete, production-grade IAM architecture for Vertex Health Systems — a fictional regional health system designed to represent the complexity, legacy debt, and regulatory requirements of real large healthcare organisations. All eight major IAM design decisions are documented as Architecture Decision Records (ADRs).",
         [10, 24])

    h2(doc, "11.1  Organisation Profile and Problem Statement")
    cite(doc,
         "Vertex Health Systems: 85,000 employees across 28 hospitals and 340 outpatient clinics. 4.2 million patient portal accounts. $12.4 billion annual revenue. The programme trigger: a supply chain ransomware near-miss — a vendor VPN account with no MFA, 14-day dwell time before detection, active exfiltration of 340,000 patient records.",
         [24, 10])
    body(doc, "Starting state: 4 AD forests, 18 domains (legacy hospital acquisitions), Oracle OAM federation (end-of-life in 18 months), homegrown PHP patient portal, no PAM, no IGA, no MFA for most users, mixed PKI with expired certificates on internal applications.")

    h2(doc, "11.2  Architecture Decision Records")
    analogy_box(doc,
        "The Architect's Decision Log",
        "An ADR (Architecture Decision Record) is an architect's decision journal. It records not just what was decided, but why — and critically, what alternatives were considered and rejected. Future engineers reading the ADR understand the constraints that shaped the design. Without ADRs, engineers inherit a system with no explanation of why it was built this way, leading to ill-informed changes that break assumptions the original architect never documented.")
    cite(doc,
         "The IAM-ADR Framework evaluates every major decision across seven forces: Security (threat model), Usability (user experience friction), Compliance (regulatory requirements), Operability (team capacity), Scalability (user/transaction volume), Cost (budget constraints), and Vendor lock-in (exit risk). Each ADR documents: Context, Decision, Rationale, Consequences (positive/negative/neutral), and Review Date.",
         [2])

    key_term(doc, "ADR-02: PHS vs. AD FS",
             "PHS chosen for Vertex Health. Rationale: 99.99% auth SLA impossible with AD FS across 28 hospitals on 1.5 Mbps WAN links. WAN outage = cloud auth outage with AD FS. PHS validates in cloud — WAN outage has zero impact on cloud authentication. Validated by two WAN outages during Month 4 and Month 11: PHS users unaffected.", 16)
    key_term(doc, "ADR-07: Entra External ID vs. Auth0",
             "Entra External ID chosen for patient portal CIAM. Rationale: HIPAA BAA for Auth0 requires Private Cloud deployment at 3–5x cost premium. Entra External ID provides HIPAA BAA on standard Azure US-region deployment within approved budget. Auth0 Private Cloud rejected on cost despite superior developer experience.", 9)

    h2(doc, "11.3  Clinical Authentication — 8-Second SLA")
    cite(doc,
         "Clinical staff authentication SLA: 8 seconds from badge tap to EHR (Epic) access. Solution: HID proximity badge with PIV-compliant X.509 certificate → PKINIT (Kerberos + certificate) → TGT → Seamless SSO → Entra ID token → Epic EHR. Measured result: 3.7 seconds (LAN), 5.1 seconds (WAN). Both under SLA.",
         [22, 15])

    h2(doc, "11.4  Programme Outcomes")
    cite(doc,
         "Month 24 results: CISA ZT Identity Pillar — Optimal (from Traditional). MFA coverage — 97.2% (from 0%). Dwell time (MTTD) — 2.8 hours (from 14 days). Legacy auth sign-ins — 23/day (from ~12,400/day). Critical attack paths — 89 (from 847). HITRUST CSF certified. Cyber insurance renewed at Month 3 on proof of MFA deployment.",
         [6, 10])

    h2(doc, "11.5  HIPAA Security Rule Compliance Mapping")
    cite(doc,
         "HIPAA Security Rule §164.312 Technical Safeguards require: Access control (unique user IDs, emergency access, automatic logoff, encryption/decryption). Audit controls (hardware/software/procedural mechanisms to record activity). Integrity (PHI alteration/destruction protection). Authentication (verify person or entity seeking access). Transmission security (encryption of PHI in transit).",
         [24])

    self_check(doc, [
        "What are the seven IAM architecture forces evaluated in the Vertex Health ADR framework?",
        "Why was PHS chosen over AD FS for Vertex Health? What specific failure scenario made AD FS unacceptable?",
        "Describe the clinical authentication flow from badge tap to Epic EHR access, naming each protocol used.",
        "What is the difference between HITRUST CSF and HIPAA? Why did Vertex Health pursue both?",
        "What was the highest-ROI security control implemented in the Vertex Health programme, and why?"
    ])
    interview_box(doc, [
        "Walk me through an Architecture Decision Record. What sections does it contain, and why is the Rationale section the most important?",
        "A healthcare client needs authentication in under 8 seconds for clinical staff. What architecture would you design?",
        "HIPAA §164.312 requires 'unique user identification.' What identity controls satisfy this requirement?",
        "How would you measure the ROI of a Zero Trust programme to a healthcare board?"
    ])
    doc.add_page_break()


def chapter_12(doc):
    h1(doc, "Chapter 12: AI Identity Security")
    cite(doc,
         "Artificial intelligence is transforming both the attack surface and the defensive capabilities of identity security. LLMs and AI agents introduce new identity patterns (AI workload identity, agent delegation), new attack vectors (prompt injection, AI-assisted SoD gaming), and new defensive tools (AI-assisted access review, anomaly detection). IAM architects must understand both sides.",
         [7, 14])

    h2(doc, "12.1  LLM Access Control Stack")
    analogy_box(doc,
        "The Bank Teller Window",
        "An LLM handling sensitive queries is like a bank teller window. Before you can ask about your account, you must (1) show ID at the door (identity gate), (2) pass through the security checkpoint (API gateway with rate limiting), (3) speak to the teller who only sees information relevant to your account (context assembly with access-controlled RAG). The teller doesn't have keys to every vault — they see only what's appropriate for your query.")
    cite(doc,
         "The LLM access control stack has five layers: (1) Identity gate — authenticate the user before any query reaches the LLM. (2) API gateway — rate limiting, quota enforcement, token counting. (3) Context assembly — RAG retrieval with server-side document filtering (OData filter at search engine level, not in application code). (4) LLM inference — model processes only authorised context. (5) Output filter — scan response for injection artifacts or unauthorised content.",
         [7, 14])
    key_term(doc, "Server-Side RAG Filtering", "Document namespace filter applied at the vector search engine (e.g., Azure AI Search OData filter), not in application code post-retrieval. Critical: unauthorised documents must never reach application memory — server-side enforcement only.", 7)

    h2(doc, "12.2  AI Agent Identity Patterns")
    cite(doc,
         "AI agents are autonomous programs that use LLMs to reason and take actions via tools. Four identity patterns: (1) Stateless — single-turn, no persistent identity. (2) Tool-using — has service principal, calls external APIs. (3) Persistent — maintains session state, long-running tasks. (4) Multi-agent — orchestrator spawns sub-agents with delegated permissions.",
         [7])
    key_term(doc, "Principle of Least Privilege for Agents", "AI agents should have the minimum permissions needed for their specific task. Read-only by default; write permissions require explicit business justification. Tool allowlist (not blocklist): the agent can only call tools explicitly granted, not all tools except blocked ones.", 7)
    key_term(doc, "Agent Delegation Token", "A JWT issued by an orchestrator agent to a sub-agent, scoped to specific allowed_tools, with a short TTL (≤ 5 minutes). The sub-agent validates the token before acting.", 7)

    h2(doc, "12.3  Prompt Injection — Taxonomy and Defence")
    analogy_box(doc,
        "The Forged Work Order",
        "An indirect prompt injection attack is like a forged work order slipped into a contractor's inbox. The contractor (AI agent) reads all their emails (processes all data) and acts on instructions. A malicious party puts a fake work order in the pile — 'Install a backdoor in Room 401.' Unless the contractor verifies the source of every instruction, they may comply with the forged order.")
    cite(doc,
         "OWASP LLM01 — Prompt Injection: Attackers craft inputs that override the LLM's instructions. Direct injection: user directly inserts adversarial instructions. Indirect injection: adversarial content embedded in data the LLM processes (email body, document, web page). Tool poisoning: malicious tool descriptions that cause the LLM to call tools with attacker-controlled parameters.",
         [14])
    key_term(doc, "Instruction/Data Separation", "Primary prompt injection defence: clearly delimit the boundary between instructions (trusted system prompt) and data (untrusted user-provided content). The LLM must be instructed to never treat content in the data section as instructions.", 14)

    h2(doc, "12.4  AI-Assisted Attacks")
    cite(doc,
         "AI enables three identity-specific attack categories at higher velocity and lower skill threshold: (1) AI-generated phishing — personalised lures from LinkedIn/social data, targeting specific MFA fatigue patterns. (2) Deepfake audio/video — impersonating executives for social engineering of IT helpdesk. (3) AI-automated SoD gaming — systematically requesting conflicting entitlements with calculated intervals to evade threshold detection.",
         [14, 12])

    h2(doc, "12.5  Defensive AI in IAM")
    cite(doc,
         "AI provides three major defensive capabilities for IAM: (1) AI-assisted access reviews — LLM analyses user profile, peer group comparison, usage data, and SoD conflicts to recommend APPROVE/REVOKE/ESCALATE with reasoning. Reduces reviewer fatigue; improves decision quality. (2) Anomaly detection — ML models detect behavioural anomalies in authentication patterns that rule-based systems miss. (3) Natural language IGA policies — allows business stakeholders to author access policies in plain English, translated to enforcement logic by LLM.",
         [7])

    h2(doc, "12.6  NIST AI RMF Applied to Identity")
    cite(doc,
         "NIST AI RMF 1.0 [AI 100-1] provides four functions for managing AI risk: GOVERN (policies for AI development and deployment), MAP (identify AI risks relevant to the system), MEASURE (quantify risk — false negative rate, false positive rate, bias metrics), MANAGE (implement controls to mitigate identified risks). For AI access review: MEASURE specifically requires tracking false negative rate (AI approves; human revokes) with alert threshold ≤ 5%.",
         [7])

    self_check(doc, [
        "Why must RAG document filtering be applied server-side (at the search engine) rather than in application code?",
        "What is the difference between direct and indirect prompt injection? Give an example of each.",
        "What is an agent delegation token, and what claims must it contain?",
        "Define false negative rate in the context of AI access review. Why is a 5% FN threshold used?",
        "How does AI-automated SoD gaming evade traditional detection, and what signal reveals it?"
    ])
    interview_box(doc, [
        "An AI agent has write access to your email system. What controls would you put in place to prevent prompt injection from causing it to send unauthorised emails?",
        "How would you apply the NIST AI RMF to an AI-assisted access certification programme?",
        "What is the LLM access control stack? Name all five layers and what each enforces.",
        "If your AI access review system has a 12% false negative rate, what does that mean and what do you do?"
    ])
    doc.add_page_break()


# ─────────────────────────────────────────────────────────────────────────────
# COVER PAGE AND TOC
# ─────────────────────────────────────────────────────────────────────────────

def make_cover(doc):
    doc.add_paragraph()
    doc.add_paragraph()
    doc.add_paragraph()

    title = doc.add_paragraph()
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    rt = title.add_run("Enterprise IAM Architecture")
    rt.font.name  = FONT_NAME
    rt.font.size  = Pt(28)
    rt.font.bold  = True
    rt.font.color.rgb = CLR_DARK_BLUE

    sub = doc.add_paragraph()
    sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    rs = sub.add_run("A Complete Practitioner's Textbook")
    rs.font.name  = FONT_NAME
    rs.font.size  = Pt(16)
    rs.font.color.rgb = CLR_MID_BLUE

    doc.add_paragraph()
    doc.add_paragraph()

    desc = doc.add_paragraph()
    desc.alignment = WD_ALIGN_PARAGRAPH.CENTER
    chapters = [
        "Directory Services  ·  PKI  ·  Federation Protocols",
        "PAM  ·  Zero Trust  ·  IGA  ·  Microsoft Entra ID",
        "Auth0 CIAM  ·  Defender XDR  ·  CAD Capstone  ·  AI Identity Security"
    ]
    for line in chapters:
        rd = desc.add_run(line + "\n")
        rd.font.name  = FONT_NAME
        rd.font.size  = Pt(11)
        rd.font.color.rgb = RGBColor(0x40, 0x40, 0x40)

    doc.add_paragraph()
    doc.add_paragraph()

    meta = doc.add_paragraph()
    meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for line in [
        "12 Chapters  ·  48 Hands-On Labs  ·  100 Interview Questions",
        "HIPAA  ·  HITRUST  ·  SOX  ·  PCI DSS  ·  NIST AI RMF",
        "",
        "Portfolio Edition — Cybersec by Laurel"
    ]:
        rm = meta.add_run(line + "\n")
        rm.font.name = FONT_NAME
        rm.font.size = Pt(10)
        rm.font.color.rgb = RGBColor(0x60, 0x60, 0x60)

    doc.add_page_break()


def make_toc_page(doc):
    h1(doc, "Table of Contents")
    body(doc, "Update this table of contents in Microsoft Word by pressing Ctrl+A then F9, or right-clicking the field and selecting 'Update Field'.")
    doc.add_paragraph()
    add_toc_field(doc)
    doc.add_page_break()


def make_preface(doc):
    h1(doc, "Preface")
    cite(doc,
         "This textbook presents Enterprise Identity and Access Management (IAM) architecture from the practitioner's perspective — for engineers who need to design, build, defend, and explain IAM systems at the architect level. Every concept is introduced with a real-world analogy before the formal definition, grounding abstract security concepts in tangible experience.",
         [1, 17])
    body(doc, "The textbook is structured in three parts:")
    bullet(doc, "Foundations (Chapters 1–4): Identity concepts, directory services, PKI, and federation protocols — the building blocks every IAM architect must own.")
    bullet(doc, "Advanced Controls (Chapters 5–8): PAM, Zero Trust, IGA, and Entra ID — the operational and architectural layers that mature programmes deploy.")
    bullet(doc, "Applied Architecture (Chapters 9–12): Auth0 CIAM, Defender XDR implementation, the Vertex Health Systems capstone, and AI identity security — synthesis and application.")
    doc.add_paragraph()
    body(doc, "Each chapter follows a consistent structure: Analogy → Formal Definition → Architect-Grade Detail → Worked Examples → Self-Check Questions → Interview Cheat Sheet. The 12 chapters collectively contain 48 hands-on labs designed for Microsoft 365 Developer Tenant (free) or Auth0 free tier environments.")
    doc.add_paragraph()
    body(doc, "Inline citations [N] reference the authoritative sources listed in the References section at the end of this document. All technical claims are grounded in NIST, IETF, OASIS, or vendor-authoritative documentation.")
    doc.add_page_break()


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    doc = Document()
    setup_styles(doc)

    # Page margins
    section = doc.sections[0]
    section.top_margin    = Cm(2.5)
    section.bottom_margin = Cm(2.5)
    section.left_margin   = Cm(3.0)
    section.right_margin  = Cm(2.5)

    # Cover
    make_cover(doc)

    # Table of Contents
    make_toc_page(doc)

    # Preface
    make_preface(doc)

    # Chapters
    chapter_01(doc)
    chapter_02(doc)
    chapter_03(doc)
    chapter_04(doc)
    chapter_05(doc)
    chapter_06(doc)
    chapter_07(doc)
    chapter_08(doc)
    chapter_09(doc)
    chapter_10(doc)
    chapter_11(doc)
    chapter_12(doc)

    # References
    add_reference_list(doc)

    doc.save(OUTPUT_FILE)
    print(f"\nSaved: {OUTPUT_FILE}")
    print(f"  Open in Word, press Ctrl+A then F9 to populate the Table of Contents.")


if __name__ == "__main__":
    main()
