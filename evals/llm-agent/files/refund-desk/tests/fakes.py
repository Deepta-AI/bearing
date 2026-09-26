"""Offline fakes. No test in this repository may call a real provider."""

import itertools

from app.llm import ModelResponse, Usage


class FakeGateway:
    def __init__(self, fail_times: int = 0):
        self.calls = []
        self._seen = {}
        self._fail = fail_times
        self._ids = itertools.count(1)

    def create_refund(self, order_id, amount_paise, idempotency_key):
        self.calls.append((order_id, amount_paise, idempotency_key))
        if idempotency_key and idempotency_key in self._seen:
            return self._seen[idempotency_key]
        result = {"id": f"rf_fake_{next(self._ids):04d}", "status": "succeeded"}
        if idempotency_key:
            self._seen[idempotency_key] = result
        if self._fail:
            self._fail -= 1
            from app.payments import GatewayError

            raise GatewayError("timeout after the refund was created")
        return result


class FakeMailer:
    def __init__(self):
        self.sent = []

    def send(self, to, subject, body):
        self.sent.append((to, subject, body))
        return f"msg_{len(self.sent)}"


class ScriptedModel:
    """Returns the scripted responses in order and records every request."""

    def __init__(self, responses):
        self._responses = list(responses)
        self.requests = []

    def create(self, *, model, system, messages, tools, max_tokens):
        self.requests.append({"model": model, "system": system, "messages": list(messages), "tools": tools})
        if not self._responses:
            raise AssertionError("ScriptedModel ran out of responses")
        return self._responses.pop(0)


def text(t, usage=(900, 120)):
    return ModelResponse([{"type": "text", "text": t}], "end_turn", Usage(*usage))


def tool_call(name, args, call_id="tu_1", usage=(900, 80)):
    return ModelResponse([{"type": "tool_use", "id": call_id, "name": name, "input": args}], "tool_use", Usage(*usage))
