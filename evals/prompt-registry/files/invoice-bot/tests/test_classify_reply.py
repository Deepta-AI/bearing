from invoicebot.classify import classify
from invoicebot.llm import Response
from invoicebot.reply import draft_reply


class Fake:
    def __init__(self, text):
        self.text = text
        self.calls = []

    def complete(self, *, model, system, user, tag, max_tokens):
        self.calls.append({"model": model, "system": system, "user": user})
        return Response(self.text, model)


def test_classify_unknown_label_is_other():
    assert classify("d1", "Hello", "Buy our new spices", Fake("Promotion")) == "other"


def test_classify_known_label():
    assert classify("d2", "Invoice 44", "Please find attached", Fake(" Invoice\n")) == "invoice"


def test_reply_mentions_vendor():
    f = Fake("Dear Acme ...")
    draft_reply("Acme Traders", "GSTIN missing", f)
    assert "Acme Traders" in f.calls[0]["user"]
