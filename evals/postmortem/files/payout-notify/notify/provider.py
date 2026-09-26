"""Client for the transactional email provider."""


class ProviderTimeout(Exception):
    """The provider did not answer within the client timeout."""


class Provider:
    """Sends one templated message per call.

    The provider accepts a message as soon as it has read the request, before
    it answers; a client-side timeout therefore does not mean the message was
    not accepted. The API takes an optional idempotency key: a repeat of the
    same key within 24 hours is acknowledged and not sent again.
    """

    def __init__(self, transport, timeout_s):
        self.transport = transport
        self.timeout_s = timeout_s

    def send(self, to, template, data, idempotency_key=None):
        payload = {"to": to, "template": template, "data": data}
        headers = {}
        if idempotency_key:
            headers["Idempotency-Key"] = idempotency_key
        return self.transport(payload, headers, self.timeout_s)
