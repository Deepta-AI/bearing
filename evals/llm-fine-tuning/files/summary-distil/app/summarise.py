SYSTEM = (
    "Summarise this closed support ticket in three lines: the customer's "
    "problem, what resolved it, and any follow-up owed. Use only facts in the ticket."
)


def build_messages(ticket_text: str) -> list[dict]:
    return [{"role": "system", "content": SYSTEM}, {"role": "user", "content": ticket_text}]
