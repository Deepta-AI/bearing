"""Keyword routing rules (2023). First match wins; no match goes to general."""

QUEUES = ["billing", "invoicing", "integrations", "account_access", "bug_report", "general"]

RULES = [
    ("account_access", ["password", "login", "log in", "2fa", "locked out", "sso"]),
    ("integrations", ["xero", "quickbooks", "zapier", "api key", "webhook", "sync"]),
    ("billing", ["charge", "card", "subscription", "plan", "refund", "billing"]),
    ("invoicing", ["invoice template", "gst", "tax", "invoice number", "credit note"]),
    ("bug_report", ["error", "crash", "broken", "not working", "bug", "500"]),
]


def route(subject: str, body: str) -> str:
    text = f"{subject} {body}".lower()
    for queue, words in RULES:
        if any(w in text for w in words):
            return queue
    return "general"
