import json

from extract.vlm import FIELDS, parse_response


def test_parse_response_fills_every_field():
    reply = json.dumps({"heat_no": {"value": " H12345 ", "confidence": 0.93}})
    out = parse_response(reply)
    assert set(out) == set(FIELDS)
    assert out["heat_no"] == {"value": "H12345", "confidence": 0.93}
    assert out["grade"] == {"value": "", "confidence": 0.0}
