from dataclasses import dataclass, field


@dataclass
class Session:
    conversation_id: str
    customer_id: str  # from the app's auth token; the customer is signed in
    messages: list[dict] = field(default_factory=list)
