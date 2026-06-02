"""
Script 12-6: AI Access Review Accuracy Measurement
Tracks AI access certification recommendation accuracy vs. human final decisions.

Metrics:
  - Overall accuracy %
  - False positive rate: AI recommends REVOKE, human approves (over-revocation)
  - False negative rate: AI recommends APPROVE, human revokes (missed real risk)

Alert thresholds:
  - False negative > 5%  → AI is missing real risks (unacceptable)
  - False positive > 20% → Reviewer fatigue likely (reviewers rubber-stamp AI)

Run after each certification campaign; trend over time to measure model improvement.

Chapter 12 §12.5 — Defensive AI in IAM
"""

import json
import logging
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import Literal

logger = logging.getLogger(__name__)

Recommendation = Literal["APPROVE", "REVOKE", "ESCALATE"]


@dataclass
class ReviewComparison:
    """A single certification item where both AI and human decisions are recorded."""
    item_id:              str
    user_id:              str
    entitlement_id:       str
    ai_recommendation:    Recommendation
    ai_confidence:        float
    human_decision:       Recommendation    # "APPROVE" or "REVOKE" (humans resolve ESCALATEs)
    campaign_id:          str
    reviewed_at:          datetime


@dataclass
class AccuracyReport:
    campaign_id:          str
    total_items:          int
    correct:              int
    false_positives:      int    # AI: REVOKE, Human: APPROVE
    false_negatives:      int    # AI: APPROVE, Human: REVOKE
    escalations_resolved: int
    accuracy_pct:         float
    false_positive_rate:  float
    false_negative_rate:  float
    escalation_rate:      float
    alert_fn_threshold:   bool   # False if false_negative_rate > threshold
    alert_fp_threshold:   bool   # False if false_positive_rate > threshold
    bias_assessment:      dict
    generated_at:         datetime


def compute_accuracy_report(
    comparisons: list[ReviewComparison],
    campaign_id: str,
    fn_threshold: float = 0.05,
    fp_threshold: float = 0.20,
) -> AccuracyReport:
    """
    Computes accuracy metrics from a list of AI vs human comparisons.
    Excludes items where AI said ESCALATE (those are handled separately).
    """

    # Separate clear decisions from escalations
    clear_decisions  = [c for c in comparisons if c.ai_recommendation != "ESCALATE"]
    escalations      = [c for c in comparisons if c.ai_recommendation == "ESCALATE"]

    total    = len(clear_decisions)
    correct  = 0
    fp_count = 0   # AI: REVOKE, Human: APPROVE
    fn_count = 0   # AI: APPROVE, Human: REVOKE

    for item in clear_decisions:
        ai_binary    = "REVOKE" if item.ai_recommendation == "REVOKE" else "APPROVE"
        human_binary = "REVOKE" if item.human_decision == "REVOKE" else "APPROVE"

        if ai_binary == human_binary:
            correct += 1
        elif ai_binary == "REVOKE" and human_binary == "APPROVE":
            fp_count += 1   # Over-revocation
        elif ai_binary == "APPROVE" and human_binary == "REVOKE":
            fn_count += 1   # Missed risk

    accuracy_pct   = (correct / total * 100) if total > 0 else 0.0
    fp_rate        = (fp_count / total) if total > 0 else 0.0
    fn_rate        = (fn_count / total) if total > 0 else 0.0
    escalation_rate = (len(escalations) / len(comparisons)) if comparisons else 0.0

    # Bias assessment: are there systematic errors by entitlement risk level?
    bias = {}
    for risk_level in ["LOW", "MEDIUM", "HIGH", "CRITICAL"]:
        risk_items = [c for c in clear_decisions if hasattr(c, 'entitlement_risk') and getattr(c, 'entitlement_risk', '') == risk_level]
        if risk_items:
            risk_fn = sum(1 for c in risk_items if c.ai_recommendation == "APPROVE" and c.human_decision == "REVOKE")
            bias[risk_level] = {
                "count": len(risk_items),
                "false_negatives": risk_fn,
                "fn_rate": risk_fn / len(risk_items),
            }

    report = AccuracyReport(
        campaign_id          = campaign_id,
        total_items          = total,
        correct              = correct,
        false_positives      = fp_count,
        false_negatives      = fn_count,
        escalations_resolved = len(escalations),
        accuracy_pct         = round(accuracy_pct, 1),
        false_positive_rate  = round(fp_rate, 3),
        false_negative_rate  = round(fn_rate, 3),
        escalation_rate      = round(escalation_rate, 3),
        alert_fn_threshold   = fn_rate > fn_threshold,
        alert_fp_threshold   = fp_rate > fp_threshold,
        bias_assessment      = bias,
        generated_at         = datetime.utcnow(),
    )

    return report


def print_report(report: AccuracyReport, fn_threshold: float, fp_threshold: float):
    print(f"\n{'='*60}")
    print(f"  AI ACCESS REVIEW ACCURACY REPORT")
    print(f"  Campaign: {report.campaign_id}")
    print(f"  Generated: {report.generated_at.strftime('%Y-%m-%d %H:%M UTC')}")
    print(f"{'='*60}")
    print(f"\n  Items with clear AI decision:  {report.total_items}")
    print(f"  Correct:                        {report.correct} ({report.accuracy_pct}%)")
    print(f"  False positives (over-revoke):  {report.false_positives} ({report.false_positive_rate:.1%})")
    print(f"  False negatives (missed risk):  {report.false_negatives} ({report.false_negative_rate:.1%})")
    print(f"  Escalations resolved by human:  {report.escalations_resolved} ({report.escalation_rate:.1%})")

    print(f"\n  THRESHOLDS:")
    fn_color = "⚠️  ALERT" if report.alert_fn_threshold else "✓ OK"
    fp_color = "⚠️  ALERT" if report.alert_fp_threshold else "✓ OK"
    print(f"  False negative rate {report.false_negative_rate:.1%} (max {fn_threshold:.0%}): {fn_color}")
    print(f"  False positive rate {report.false_positive_rate:.1%} (max {fp_threshold:.0%}): {fp_color}")

    if report.alert_fn_threshold:
        print(f"\n  ⚠️  ACTION REQUIRED: AI is missing real risks (FN > {fn_threshold:.0%})")
        print(f"     → Retrain or fine-tune recommendation model")
        print(f"     → Increase human review of APPROVE recommendations for high-risk entitlements")

    if report.alert_fp_threshold:
        print(f"\n  ⚠️  WARNING: High over-revocation rate (FP > {fp_threshold:.0%})")
        print(f"     → Risk: reviewers may be rubber-stamping AI (automation bias)")
        print(f"     → Review false positive patterns — may indicate overly aggressive AI policy")


# --- Demo ---
if __name__ == "__main__":
    from datetime import timedelta
    import random

    random.seed(42)
    now = datetime.utcnow()

    # Simulate 100 certification items
    comparisons = []
    for i in range(100):
        # 85% accuracy: AI and human agree
        ai_rec = random.choice(["APPROVE", "REVOKE", "ESCALATE"])
        if random.random() < 0.85:
            human = ai_rec if ai_rec != "ESCALATE" else random.choice(["APPROVE", "REVOKE"])
        else:
            human = "REVOKE" if ai_rec == "APPROVE" else "APPROVE"

        comparisons.append(ReviewComparison(
            item_id           = f"ITEM-{i:03d}",
            user_id           = f"USER-{i % 20:03d}",
            entitlement_id    = f"ENT-{i % 30:03d}",
            ai_recommendation = ai_rec,
            ai_confidence     = round(random.uniform(0.6, 0.99), 2),
            human_decision    = human,
            campaign_id       = "Q2-2026",
            reviewed_at       = now - timedelta(days=random.randint(0, 30)),
        ))

    report = compute_accuracy_report(comparisons, "Q2-2026")
    print_report(report, fn_threshold=0.05, fp_threshold=0.20)

    # Save report
    report_dict = asdict(report)
    report_dict["generated_at"] = report.generated_at.isoformat()
    with open(f"AIReviewAccuracy_{now.strftime('%Y%m%d')}.json", "w") as f:
        json.dump(report_dict, f, indent=2, default=str)
    print(f"\n  Report saved: AIReviewAccuracy_{now.strftime('%Y%m%d')}.json")
