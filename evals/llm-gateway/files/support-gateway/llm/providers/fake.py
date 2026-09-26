"""Scripted provider for tests: returns queued results or raises queued errors."""

from llm.types import ProviderResult, Usage


class FakeProvider:
    def __init__(self, script=None):
        self.script = list(script or [])
        self.calls = []

    def complete(self, model, req, route):
        self.calls.append((model, req))
        item = self.script.pop(0) if self.script else ProviderResult("ok", model, "end_turn", Usage(10, 2))
        if isinstance(item, Exception):
            raise item
        return item
