"""The one place the vision language model is called."""

import base64
import json
import os
import urllib.request

MODEL = "vlm-extract-2026-08"
FIELDS = ["certificate_no", "heat_no", "issue_date", "grade", "yield_mpa"]

PROMPT = (
    "You are reading a steel mill test certificate. Return JSON with the keys "
    + ", ".join(FIELDS)
    + ". For each key give {\"value\": string, \"confidence\": number from 0 to 1}. "
    "Dates as YYYY-MM-DD. Yield strength in MPa, digits only."
)


def parse_response(text):
    """Turn the model's JSON reply into {field: {"value": str, "confidence": float}}."""
    data = json.loads(text)
    out = {}
    for field in FIELDS:
        item = data.get(field) or {}
        out[field] = {
            "value": str(item.get("value", "")).strip(),
            "confidence": float(item.get("confidence", 0.0)),
        }
    return out


def extract_fields(path):
    """Send one scan to the model and return its fields."""
    with open(path, "rb") as fh:
        image = base64.b64encode(fh.read()).decode()
    body = json.dumps({"model": MODEL, "prompt": PROMPT, "image": image}).encode()
    req = urllib.request.Request(
        os.environ["VLM_URL"], data=body, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return parse_response(json.load(resp)["output"])
