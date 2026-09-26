import json

from invoicebot.extract import extract
from invoicebot.llm import RecordedLLM, Response


class Fake:
    def __init__(self, text):
        self.text = text
        self.calls = []

    def complete(self, *, model, system, user, tag, max_tokens):
        self.calls.append({"model": model, "system": system, "user": user})
        return Response(self.text, model)


def test_extract_parses_json():
    f = Fake('{"vendor_name": "A", "gstin": null, "invoice_number": "1", "invoice_date": "2026-08-01", "total": 10.0, "currency": "INR"}')
    out = extract("x", "invoice text", f)
    assert out["vendor_name"] == "A"
    assert "invoice text" in f.calls[0]["user"]


def test_recorded_first_invoice_replays():
    row = json.loads(open("tests/fixtures/invoices.jsonl").readline())
    out = extract(row["id"], row["text"], RecordedLLM())
    assert out["invoice_number"] == row["expected"]["invoice_number"]
