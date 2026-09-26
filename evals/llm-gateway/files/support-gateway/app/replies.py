from llm.gateway import default_gateway
from llm.types import LLMRequest


def draft_reply(tenant_id: str, ticket_text: str, gateway=None) -> str:
    gw = gateway or default_gateway()
    return gw.complete(
        LLMRequest(
            feature="reply_draft",
            tenant_id=tenant_id,
            system="Draft a short, polite reply to this support ticket.",
            messages=[{"role": "user", "content": ticket_text}],
        )
    ).text
