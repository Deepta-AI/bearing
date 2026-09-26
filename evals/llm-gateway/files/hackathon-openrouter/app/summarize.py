import anthropic

client = anthropic.Anthropic()


def summarize(note: str) -> str:
    msg = client.messages.create(
        model="claude-sonnet-5",
        max_tokens=400,
        system="Summarise this standup note in one short paragraph.",
        messages=[{"role": "user", "content": note}],
    )
    return msg.content[0].text
