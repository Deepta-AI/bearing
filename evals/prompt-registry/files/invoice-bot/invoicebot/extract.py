from __future__ import annotations

import json

from .llm import LLMClient


def extract(invoice_id: str, invoice_text: str, client: LLMClient, currency: str = "INR") -> dict:
    system = f"""You are an expert accounts payable assistant for Ferncrest Foods.
Extract the following fields from the invoice the user sends and respond in JSON like this:
{{"vendor_name": "...", "gstin": "...", "invoice_number": "...", "invoice_date": "YYYY-MM-DD", "total": 0.0, "currency": "{currency}"}}
Always fill in every field. Dates must be YYYY-MM-DD. The total is the grand total including tax."""
    user = f"Here is the invoice:\n{invoice_text}"
    resp = client.complete(model="claude-sonnet-5", system=system, user=user, tag=invoice_id, max_tokens=500)
    return json.loads(resp.text)
