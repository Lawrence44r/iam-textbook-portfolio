# Chapter 12: AI Identity Security Scripts

Python and PowerShell scripts for AI identity controls: RAG access control, AI agent identity patterns, prompt injection defense, SoD gaming detection, and AI access review accuracy measurement.

## Prerequisites
```bash
pip install anthropic azure-identity azure-search-documents cryptography PyJWT python-dotenv
```

```bash
# Environment variables required
export ANTHROPIC_API_KEY="sk-ant-..."
export AZURE_CLIENT_ID="..."
export AZURE_TENANT_ID="..."
export AZURE_SEARCH_ENDPOINT="https://your-search.search.windows.net"
export AZURE_SEARCH_INDEX="documents"
```

## Scripts

### Script 12-1: RAG Pipeline with Document-Level Access Control
**File:** `rag_access_control.py`  
**Purpose:** Production RAG query pipeline with server-side document namespace filtering  
**Key design:** Filter applied at Azure AI Search level (OData filter) — not in application code after retrieval  
**Namespace mapping:** Entra ID group memberships → document namespaces (public/internal/confidential/restricted/phi)  
**Audit:** Every query logged with user ID, query hash, document IDs retrieved, token counts  
**Critical note:** Unauthorized documents never reach application memory — server-side enforcement only

### Script 12-2: AI Agent Identity and Tool Execution
**File:** `ai_agent_identity.py`  
**Purpose:** Demonstrates correct AI agent design with least-privilege tool access and human-in-the-loop  
**Pattern:** Tool allowlist (not blocklist) | read-only by default | write tools require confirmation token | all tool calls audited  
**Includes:** Token caching for agent identity, tool execution wrapper with instruction provenance validation

### Script 12-3: Agent-to-Agent Delegation Token
**File:** `agent_delegation.py`  
**Purpose:** JWT-based delegation token pattern for multi-agent systems  
**Implements:** `AgentIdentity` class — orchestrator issues scoped delegation tokens to sub-agents  
**Token claims:** `iss` (orchestrator), `sub` (sub-agent), `allowed_tools` list, `max_recursion_depth`, `human_approval_required`  
**Security:** Sub-agent validates token before acting; refuses if expired, invalid algorithm, or tool not in allowlist

### Script 12-4: Prompt Injection Defense Patterns
**File:** `prompt_injection_defense.py`  
**Purpose:** Demonstrates instruction/data separation and tool execution validation  
**Defenses:** System prompt boundary declaration | tool wrapper with instruction source check | destructive tool confirmation token | output scanning for injection indicators  
**Test cases:** Direct injection, indirect injection via document, tool poisoning attempt

### Script 12-5: SoD Gaming Pattern Detection
**File:** `Find-SoDGamingPatterns.ps1`  
**Purpose:** Detect AI-assisted cumulative SoD gaming — sequential access requests that individually pass SoD checks but collectively constitute a conflict  
**Detects:** Requests across conflicting SoD zones over rolling 12-month period  
**Suspicious pattern flag:** Standard deviation of request intervals < 5 days (evenly spaced = potentially automated)  
**Output:** User, conflict zone pair, days between requests, approved entitlements in conflicting zones

### Script 12-6: AI Access Review Accuracy Measurement
**File:** `measure_ai_review_accuracy.py`  
**Purpose:** Track AI access certification recommendation accuracy vs. human final decisions  
**Metrics:** Overall accuracy %, false positive rate (AI: revoke, human: approve), false negative rate (AI: approve, human: revoke)  
**Alert thresholds:** False negative > 5% (AI missing real risks), False positive > 20% (reviewer fatigue)  
**Use:** Run after each certification campaign; trend over time

### Script 12-7: AI-Assisted Access Review Engine
**File:** `ai_access_review.py`  
**Purpose:** Generate AI recommendations for access certification items using Claude  
**Input per item:** User profile, entitlement details, peer group comparison, usage statistics, SoD risk flags  
**Output:** APPROVE/REVOKE/ESCALATE recommendation with confidence level and reasoning  
**Model choice:** `claude-haiku-4-5` for bulk processing (cost efficiency); `claude-sonnet-4-6` for escalated items  
**Human control:** No autonomous action; recommendations are inputs to human reviewer workflow

## Security Design Principles (Chapter 12)

| Principle | Implementation |
|---|---|
| Human-in-loop for writes | All write tool calls require confirmation token from authenticated user conversation |
| Instruction provenance | Tool wrapper validates: did this instruction come from user_message or system_prompt? |
| Server-side data filtering | RAG: OData filter at search engine; never filter retrieved documents in application code |
| Dedicated agent identity | Each agent has its own service principal; never share service principals across agents |
| Audit everything | Tool call: agent ID, tool name, input parameters, output hash, timestamp |
| Time-bounded delegation | Sub-agent delegation tokens expire at task end (≤ 5 minutes typical) |
| Read-only default | Agent write permissions require explicit business justification in ADR |

## NIST AI RMF Mapping

| AI RMF Function | Script | Control |
|---|---|---|
| GOVERN | AI Use Policy template | Documents permitted/prohibited AI uses in IAM |
| MAP | Script 12-5 (SoD gaming) | Maps AI-assisted attack failure mode |
| MEASURE | Script 12-6 (accuracy) | Quantifies false negative / false positive rates |
| MANAGE | Script 12-4 (injection defense) | Technical controls for prompt injection |

## Related Chapter Content
- LLM access control stack: §12.1
- AI workload identity patterns: §12.2
- Prompt injection taxonomy and defense: §12.3
- AI-assisted attacks (phishing, deepfake, SoD gaming): §12.4
- Defensive AI in IAM: §12.5
- NIST AI RMF applied to identity: §12.6
- AI use policy template: §12.6
