"""Minimal MCP server over stdio: newline-delimited JSON-RPC 2.0."""

import json
import sys
import traceback

PROTOCOL_VERSION = "2025-06-18"


class ToolError(Exception):
    """Raise from a handler to return a tool error the model can read."""

    def __init__(self, code: str, message: str, retryable: bool = False):
        super().__init__(message)
        self.code, self.message, self.retryable = code, message, retryable


class Server:
    def __init__(self, name: str, version: str = "0.1.0"):
        self.name, self.version = name, version
        self.tools: dict[str, dict] = {}

    def tool(self, name, *, description, input_schema, annotations=None, title=None):
        def register(fn):
            self.tools[name] = {
                "name": name,
                "title": title,
                "description": description,
                "inputSchema": input_schema,
                "annotations": annotations,
                "handler": fn,
            }
            return fn

        return register

    def _list(self):
        out = []
        for t in self.tools.values():
            entry = {
                "name": t["name"],
                "description": t["description"],
                "inputSchema": t["inputSchema"],
            }
            if t["title"]:
                entry["title"] = t["title"]
            if t["annotations"] is not None:
                entry["annotations"] = t["annotations"]
            out.append(entry)
        return {"tools": out}

    def _call(self, params):
        t = self.tools.get(params.get("name"))
        if t is None:
            raise LookupError(params.get("name"))
        try:
            value = t["handler"](**(params.get("arguments") or {}))
            result = {
                "content": [{"type": "text", "text": json.dumps(value, default=str)}],
                "isError": False,
            }
            if isinstance(value, dict):
                result["structuredContent"] = value
            return result
        except ToolError as e:
            body = {"code": e.code, "message": e.message, "retryable": e.retryable}
            return {
                "content": [{"type": "text", "text": json.dumps(body)}],
                "isError": True,
            }
        except Exception:
            return {
                "content": [{"type": "text", "text": traceback.format_exc()}],
                "isError": True,
            }

    def handle(self, msg: dict) -> dict | None:
        if "id" not in msg:
            return None  # notification
        method, rid = msg.get("method"), msg["id"]
        try:
            if method == "initialize":
                result = {
                    "protocolVersion": PROTOCOL_VERSION,
                    "capabilities": {"tools": {"listChanged": False}},
                    "serverInfo": {"name": self.name, "version": self.version},
                }
            elif method == "ping":
                result = {}
            elif method == "tools/list":
                result = self._list()
            elif method == "tools/call":
                result = self._call(msg.get("params") or {})
            else:
                return {
                    "jsonrpc": "2.0",
                    "id": rid,
                    "error": {"code": -32601, "message": f"method not found: {method}"},
                }
        except LookupError as e:
            return {
                "jsonrpc": "2.0",
                "id": rid,
                "error": {"code": -32602, "message": f"unknown tool: {e}"},
            }
        return {"jsonrpc": "2.0", "id": rid, "result": result}

    def run_stdio(self):
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except ValueError:
                reply = {
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {"code": -32700, "message": "parse error"},
                }
            else:
                reply = self.handle(msg)
            if reply is not None:
                sys.stdout.write(json.dumps(reply) + "\n")
                sys.stdout.flush()
