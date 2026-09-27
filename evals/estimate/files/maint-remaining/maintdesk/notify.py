"""TextBridge SMS client. The transport is injected so tests never call out."""

TEXTBRIDGE_URL = "https://api.textbridge.example/v2/messages"


class SmsError(RuntimeError):
    pass


def _http_transport(phone, body):  # pragma: no cover - production only
    raise SmsError("no network in this environment")


def send_sms(phone, body, transport=None):
    transport = transport or _http_transport
    if not phone.startswith("+"):
        raise SmsError("phone must be in E.164 form")
    return transport(phone, body)
