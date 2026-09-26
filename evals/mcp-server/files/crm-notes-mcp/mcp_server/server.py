"""CRM MCP server over stdio (newline-delimited JSON-RPC 2.0).

Run: python3 -m mcp_server.server
"""

import datetime
import json
import os
import subprocess
import sys
import traceback

from crm.client import CrmClient

crm = CrmClient(os.environ.get("CRM_BASE_URL", ""), os.environ.get("CRM_API_TOKEN", ""))


def search_accounts(name_contains="", filter=None):
    """filter is a Python expression over the account fields, e.g. "tier == 'gold' and arr_inr > 1000000"."""
    out = []
    for a in crm.accounts():
        if name_contains.lower() not in a["name"].lower():
            continue
        if filter and not eval(filter, {}, dict(a)):
            continue
        out.append(
            {"id": a["id"], "name": a["name"], "tier": a["tier"], "owner": a["owner"]}
        )
    return out


def get_account(account_id):
    return crm.account(account_id)


def list_notes(account_id):
    return crm.notes(account_id)


def add_note(account_id, text, author):
    return crm.add_note(account_id, author, text, datetime.date.today().isoformat())


def delete_note(note_id):
    crm.delete_note(note_id)
    return {"deleted": note_id}


def run_report(name):
    r = subprocess.run(
        f"python3 reports/{name}.py", shell=True, capture_output=True, text=True
    )
    return {"output": r.stdout + r.stderr}


TOOLS = {
    "search_accounts": (
        search_accounts,
        "Search accounts.",
        {
            "type": "object",
            "properties": {
                "name_contains": {"type": "string"},
                "filter": {"type": "string"},
            },
        },
    ),
    "get_account": (
        get_account,
        "Get an account.",
        {
            "type": "object",
            "properties": {"account_id": {"type": "string"}},
        },
    ),
    "list_notes": (
        list_notes,
        "List notes for an account.",
        {
            "type": "object",
            "properties": {"account_id": {"type": "string"}},
        },
    ),
    "add_note": (
        add_note,
        "Add a note.",
        {
            "type": "object",
            "properties": {
                "account_id": {"type": "string"},
                "text": {"type": "string"},
                "author": {"type": "string"},
            },
        },
    ),
    "delete_note": (
        delete_note,
        "Delete a note.",
        {
            "type": "object",
            "properties": {"note_id": {"type": "string"}},
        },
    ),
    "run_report": (
        run_report,
        "Run a report by name.",
        {
            "type": "object",
            "properties": {"name": {"type": "string"}},
        },
    ),
}


def handle(msg):
    method = msg.get("method")
    if method == "initialize":
        return {
            "protocolVersion": "2025-06-18",
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "crm", "version": "0.1.0"},
        }
    if method == "tools/list":
        return {
            "tools": [
                {"name": n, "description": d, "inputSchema": s}
                for n, (_, d, s) in TOOLS.items()
            ]
        }
    if method == "tools/call":
        name = msg["params"]["name"]
        args = msg["params"].get("arguments", {})
        print(f"[crm-mcp] call {name} {args}")
        try:
            value = TOOLS[name][0](**args)
            return {"content": [{"type": "text", "text": json.dumps(value)}]}
        except Exception:
            return {
                "content": [{"type": "text", "text": traceback.format_exc()}],
                "isError": True,
            }
    return {}


def main():
    for line in sys.stdin:
        if not line.strip():
            continue
        msg = json.loads(line)
        if "id" not in msg:
            continue
        reply = {"jsonrpc": "2.0", "id": msg["id"], "result": handle(msg)}
        sys.stdout.write(json.dumps(reply) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
