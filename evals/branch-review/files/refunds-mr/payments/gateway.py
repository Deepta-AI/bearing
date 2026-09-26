class GatewayError(Exception):
    """The card gateway could not complete the call."""


class Gateway:
    """Client for the card gateway."""

    def refund(self, order_id: int, amount_paise: int) -> str:
        raise NotImplementedError("configured per region")


class FakeGateway(Gateway):
    def __init__(self, fail=False):
        self.calls = []
        self.fail = fail

    def refund(self, order_id, amount_paise):
        if self.fail:
            raise GatewayError("gateway unavailable")
        self.calls.append((order_id, amount_paise))
        return f"rf_{len(self.calls)}"
