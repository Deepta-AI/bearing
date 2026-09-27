"""Build a JSON schema for billing events from a sample file.

Required keys and their types are taken from the first event.
"""
import json
import sys

TYPES = {str: "string", int: "integer", float: "number", bool: "boolean", dict: "object", list: "array"}

events = json.load(open(sys.argv[1], encoding="utf-8"))
first = events[0]
schema = {
    "type": "object",
    "required": sorted(first),
    "properties": {k: {"type": TYPES[type(v)]} for k, v in first.items()},
}
json.dump(schema, sys.stdout, indent=2)
