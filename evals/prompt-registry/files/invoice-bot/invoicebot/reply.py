from __future__ import annotations

from .llm import LLMClient


def draft_reply(vendor_name: str, issue: str, client: LLMClient) -> str:
    """Draft an email to the vendor about a problem the AP clerk flagged."""
    prompt = f"""Write a short, polite email to {vendor_name} about a problem with their invoice.
The problem: {issue}
Ask them to send a corrected invoice. Keep it under 120 words.
Sign off as "Accounts Payable, Ferncrest Foods"."""
    resp = client.complete(
        model="claude-sonnet-5",
        system="You write clear, polite business emails.",
        user=prompt,
        tag="reply",
        max_tokens=400,
    )
    return resp.text
