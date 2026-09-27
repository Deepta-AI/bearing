"""Validate every event in a file against a schema (required keys and types)."""
import json
import sys

TYPES = {"string": str, "integer": int, "number": (int, float), "boolean": bool, "object": dict, "array": list}

schema = json.load(open(sys.argv[1], encoding="utf-8"))
events = json.load(open(sys.argv[2], encoding="utf-8"))
errors = 0
for i, ev in enumerate(events):
    for key in schema.get("required", []):
        if key not in ev:
            print(f"event {i}: missing {key}")
            errors += 1
    for key, spec in schema.get("properties", {}).items():
        if key in ev and not isinstance(ev[key], TYPES[spec["type"]]):
            print(f"event {i}: {key} is not {spec['type']}")
            errors += 1
if errors:
    sys.exit(1)
print("schema ok")
