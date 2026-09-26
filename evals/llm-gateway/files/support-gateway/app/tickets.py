from llm.gateway import default_gateway
from llm.types import LLMRequest

LABELS = ("billing", "refund_request", "technical", "account_access", "other")


def classify_ticket(tenant_id: str, text: str, gateway=None) -> str:
    gw = gateway or default_gateway()
    resp = gw.complete(
        LLMRequest(
            feature="ticket_classify",
            tenant_id=tenant_id,
            system="Reply with one label: " + ", ".join(LABELS),
            messages=[{"role": "user", "content": text}],
        )
    )
    label = resp.text.strip()
    return label if label in LABELS else "other"
