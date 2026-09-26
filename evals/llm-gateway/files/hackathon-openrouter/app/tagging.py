import json


def tags_for(note: str) -> list[str]:
    from anthropic import Anthropic

    client = Anthropic()
    msg = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=100,
        system='Return a JSON list of up to 5 lowercase topic tags, for example ["billing", "release"].',
        messages=[{"role": "user", "content": note}],
    )
    try:
        return json.loads(msg.content[0].text)[:5]
    except ValueError:
        return []
