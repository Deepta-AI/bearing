import anthropic

LABELS = ("blocked", "on_track", "at_risk")
_client = anthropic.Anthropic()


def classify(note: str) -> str:
    msg = _client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=10,
        system="Reply with one word: blocked, on_track or at_risk.",
        messages=[{"role": "user", "content": note}],
    )
    label = msg.content[0].text.strip().lower()
    return label if label in LABELS else "on_track"
