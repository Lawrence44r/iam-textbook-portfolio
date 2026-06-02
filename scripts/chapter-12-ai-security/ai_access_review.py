"""
Script 12-7: AI-Assisted Access Review Engine
Generates AI recommendations for access certification items using Claude.

Model choice:
  - claude-haiku-4-5   → bulk processing (cost-efficient, ~1000 items/hour)
  - claude-sonnet-4-6  → escalated items requiring deeper reasoning

Human control:
  - No autonomous action: recommendations are inputs to human reviewer workflow
  - Confidence threshold: low-confidence items are escalated, not auto-decided
  - Audit: every recommendation logged with reasoning and model version

Chapter 12 §12.5 — Defensive AI in IAM
Chapter 12 §12.7 — AI Access Review Accuracy Measurement
"""

import anthropic
import json
import logging
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from typing import Literal

logger = logging.getLogger(__name__)

Recommendation = Literal["APPROVE", "REVOKE", "ESCALATE"]


@dataclass
class AccessItem:
    """Represents a single access certification item."""
    user_id:           str
    user_name:         str
    user_department:   str
    user_title:        str
    entitlement_id:    str
    entitlement_name:  str
    entitlement_system: str
    entitlement_risk:  str            # LOW / MEDIUM / HIGH / CRITICAL
    granted_date:      datetime
    last_used:         datetime | None
    usage_frequency:   str            # "daily" / "weekly" / "monthly" / "never"
    peer_usage_pct:    float          # % of peers in same role who have this entitlement
    sod_conflict:      bool
    sod_conflict_desc: str | None


@dataclass
class AccessReviewResult:
    item:           AccessItem
    recommendation: Recommendation
    confidence:     float             # 0.0 – 1.0
    reasoning:      str
    model:          str
    reviewed_at:    datetime


def build_review_prompt(item: AccessItem) -> str:
    days_since_used = (datetime.utcnow() - item.last_used).days if item.last_used else None
    days_held = (datetime.utcnow() - item.granted_date).days

    usage_summary = (
        f"Last used: {days_since_used} days ago (frequency: {item.usage_frequency})"
        if item.last_used
        else "Last used: NEVER (never accessed since granted)"
    )

    sod_note = (
        f"SoD CONFLICT: {item.sod_conflict_desc}" if item.sod_conflict else "No SoD conflicts"
    )

    return f"""You are an expert access certification reviewer. Analyze this access item and provide a recommendation.

=== ACCESS ITEM ===
User: {item.user_name} | Title: {item.user_title} | Dept: {item.user_department}
Entitlement: {item.entitlement_name} ({item.entitlement_system})
Risk Level: {item.entitlement_risk}
Held for: {days_held} days (granted: {item.granted_date.strftime('%Y-%m-%d')})
Usage: {usage_summary}
Peer comparison: {item.peer_usage_pct:.0f}% of peers in same role have this entitlement
{sod_note}

=== DECISION CRITERIA ===
REVOKE if: never used + low peer usage, or SoD conflict with no compensating control
APPROVE if: recently used, consistent with peer group, appropriate for role
ESCALATE if: high-risk entitlement + unusual usage, or SoD conflict present, or ambiguous

=== YOUR RESPONSE (JSON only, no markdown) ===
{{
  "recommendation": "APPROVE" | "REVOKE" | "ESCALATE",
  "confidence": 0.0-1.0,
  "reasoning": "2-3 sentences explaining the decision, citing specific data points"
}}"""


def review_access_item(
    item: AccessItem,
    client: anthropic.Anthropic,
    escalation_threshold: float = 0.70,
) -> AccessReviewResult:
    """
    Generate AI recommendation for a single access item.
    Uses Haiku for bulk; escalates to Sonnet if confidence is below threshold.
    """

    # Use Haiku for initial review
    model = "claude-haiku-4-5"
    prompt = build_review_prompt(item)

    response = client.messages.create(
        model=model,
        max_tokens=512,
        messages=[{"role": "user", "content": prompt}],
    )

    try:
        result_json = json.loads(response.content[0].text)
        recommendation = result_json["recommendation"]
        confidence     = float(result_json["confidence"])
        reasoning      = result_json["reasoning"]
    except (json.JSONDecodeError, KeyError) as e:
        logger.warning(f"Failed to parse Haiku response for {item.entitlement_id}: {e}")
        recommendation = "ESCALATE"
        confidence     = 0.0
        reasoning      = "AI response could not be parsed — escalating for human review"

    # Escalate low-confidence decisions to Sonnet for deeper reasoning
    if confidence < escalation_threshold or recommendation == "ESCALATE":
        logger.info(f"Escalating {item.entitlement_id} to Sonnet (confidence={confidence:.2f})")
        model = "claude-sonnet-4-6"
        response2 = client.messages.create(
            model=model,
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}],
        )
        try:
            result_json2 = json.loads(response2.content[0].text)
            recommendation = result_json2["recommendation"]
            confidence     = float(result_json2["confidence"])
            reasoning      = result_json2["reasoning"]
        except Exception:
            pass  # Keep original escalated result

    return AccessReviewResult(
        item=item,
        recommendation=recommendation,
        confidence=confidence,
        reasoning=reasoning,
        model=model,
        reviewed_at=datetime.utcnow(),
    )


# --- Demo ---
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    client = anthropic.Anthropic()

    now = datetime.utcnow()

    test_items = [
        AccessItem(
            user_id="u001", user_name="Alice Smith", user_department="Finance",
            user_title="Accounts Payable Clerk",
            entitlement_id="ENT-001", entitlement_name="AP-Create-Vendor",
            entitlement_system="SAP", entitlement_risk="HIGH",
            granted_date=now - timedelta(days=400),
            last_used=None, usage_frequency="never",
            peer_usage_pct=12.0,
            sod_conflict=True, sod_conflict_desc="AP-Create-Vendor conflicts with AP-Approve-Payment (also held)"
        ),
        AccessItem(
            user_id="u002", user_name="Bob Jones", user_department="Engineering",
            user_title="Senior Engineer",
            entitlement_id="ENT-002", entitlement_name="Prod-Read-Access",
            entitlement_system="AWS", entitlement_risk="MEDIUM",
            granted_date=now - timedelta(days=180),
            last_used=now - timedelta(days=2), usage_frequency="daily",
            peer_usage_pct=87.0,
            sod_conflict=False, sod_conflict_desc=None
        ),
    ]

    print("\n=== AI Access Review Demo ===\n")
    for item in test_items:
        result = review_access_item(item, client)
        print(f"User: {item.user_name}")
        print(f"Entitlement: {item.entitlement_name} ({item.entitlement_system})")
        print(f"Recommendation: {result.recommendation} (confidence: {result.confidence:.0%})")
        print(f"Reasoning: {result.reasoning}")
        print(f"Model: {result.model}")
        print("-" * 60)
