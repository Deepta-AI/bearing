from chat.llm import ModelResponse


class ScriptedModel:
    """Returns scripted replies in order and records every request."""

    def __init__(self, replies):
        self._replies = [
            r if isinstance(r, ModelResponse) else ModelResponse(r) for r in replies
        ]
        self.requests = []

    def create(self, *, model, system, messages, max_tokens):
        self.requests.append(
            {"model": model, "system": system, "messages": [dict(m) for m in messages]}
        )
        if not self._replies:
            raise AssertionError("ScriptedModel ran out of replies")
        return self._replies.pop(0)
