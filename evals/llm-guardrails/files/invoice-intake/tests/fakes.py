from intake.llm import ModelResponse


class ScriptedModel:
    def __init__(self, responses):
        self._responses = list(responses)
        self.requests = []

    def create(self, *, model, system, messages, tools, max_tokens):
        self.requests.append({"system": system, "messages": [dict(m) for m in messages], "tools": tools})
        if not self._responses:
            raise AssertionError("ScriptedModel ran out of responses")
        return self._responses.pop(0)


class FakeMailer:
    def __init__(self):
        self.sent = []

    def send(self, to, subject, body):
        self.sent.append((to, subject, body))
        return f"msg_{len(self.sent)}"


def text(t):
    return ModelResponse([{"type": "text", "text": t}], "end_turn", 1500, 200)


def tool_call(name, args, call_id="tu_1"):
    return ModelResponse([{"type": "tool_use", "id": call_id, "name": name, "input": args}], "tool_use", 1500, 60)
