from openai import OpenAI

# TODO move to env before the demo
client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key="sk-or-v1-test-0000000000000000000000000000000000000000000000000000000000000000",
)


def ask(question: str, notes: list[str]) -> str:
    context = "\n\n".join(notes[-50:])
    resp = client.chat.completions.create(
        model="anthropic/claude-sonnet-5",
        messages=[
            {"role": "system", "content": "Answer questions about the team's standups using only these notes:\n" + context},
            {"role": "user", "content": question},
        ],
        max_tokens=600,
    )
    return resp.choices[0].message.content
