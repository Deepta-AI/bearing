"""Test client: starts a server subprocess and speaks MCP over its stdio."""

import itertools
import json
import os
import subprocess


class ProtocolError(Exception):
    pass


class StdioClient:
    def __init__(
        self, args: list[str], env: dict | None = None, cwd: str | None = None
    ):
        full_env = dict(os.environ)
        full_env.update(env or {})
        self.proc = subprocess.Popen(
            args,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=full_env,
            cwd=cwd,
        )
        self._ids = itertools.count(1)

    def request(self, method: str, params: dict | None = None) -> dict:
        rid = next(self._ids)
        self.proc.stdin.write(
            json.dumps(
                {"jsonrpc": "2.0", "id": rid, "method": method, "params": params or {}}
            )
            + "\n"
        )
        self.proc.stdin.flush()
        line = self.proc.stdout.readline()
        if not line:
            raise ProtocolError(
                "server closed stdout; stderr: " + self.proc.stderr.read()
            )
        try:
            reply = json.loads(line)
        except ValueError:
            raise ProtocolError(f"non-protocol output on stdout: {line!r}") from None
        if reply.get("id") != rid:
            raise ProtocolError(
                f"reply id {reply.get('id')} does not match request id {rid}"
            )
        return reply

    def notify(self, method: str, params: dict | None = None) -> None:
        self.proc.stdin.write(
            json.dumps({"jsonrpc": "2.0", "method": method, "params": params or {}})
            + "\n"
        )
        self.proc.stdin.flush()

    def initialize(self) -> dict:
        r = self.request(
            "initialize",
            {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "test", "version": "0"},
            },
        )
        self.notify("notifications/initialized")
        return r["result"]

    def list_tools(self) -> list[dict]:
        return self.request("tools/list")["result"]["tools"]

    def call_tool(self, name: str, arguments: dict) -> dict:
        """Returns the JSON-RPC reply: {"result": {...}} or {"error": {...}}."""
        return self.request("tools/call", {"name": name, "arguments": arguments})

    def close(self) -> None:
        if self.proc.stdin:
            self.proc.stdin.close()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()
        for stream in (self.proc.stdout, self.proc.stderr):
            if stream:
                stream.close()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
