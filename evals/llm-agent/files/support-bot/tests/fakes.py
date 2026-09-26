from bot.llm import ModelResponse


class ScriptedModel:
    def __init__(self, responses):
        self._responses = list(responses)
        self.requests = []

    def create(self, *, model, system, messages, tools, max_tokens):
        self.requests.append({"system": system, "messages": list(messages), "tools": tools})
        if not self._responses:
            raise AssertionError("ScriptedModel ran out of responses")
        return self._responses.pop(0)


class RecordingPayments:
    def __init__(self):
        self.refunds = []

    def refund(self, order_id, amount_paise):
        self.refunds.append((order_id, amount_paise))
        return f"rf_{len(self.refunds)}"


class RecordingWarehouse:
    def __init__(self):
        self.released = []

    def release_stock(self, order_id):
        self.released.append(order_id)


def text(t):
    return ModelResponse([{"type": "text", "text": t}], "end_turn", 500, 40)


def tool_call(name, args, call_id="tu_1"):
    return ModelResponse([{"type": "tool_use", "id": call_id, "name": name, "input": args}], "tool_use", 500, 30)
