from __future__ import annotations

from .llm import LLMClient

LABELS = {"invoice", "credit_note", "statement", "other"}

SYSTEM = "You sort documents arriving in the Ferncrest Foods accounts payable inbox. Reply with exactly one label and nothing else: invoice, credit_note, statement or other. A credit note reduces an earlier invoice. A statement lists several invoices and payments for a period. Anything that is not one of these, including vendor marketing and payment reminders without an attached invoice, is other."


def classify(doc_id: str, subject: str, body: str, client: LLMClient) -> str:
    resp = client.complete(
        model="claude-haiku-4-5",
        system=SYSTEM,
        user=f"Subject: {subject}\n\n{body}",
        tag=doc_id,
        max_tokens=10,
    )
    label = resp.text.strip().lower()
    return label if label in LABELS else "other"
