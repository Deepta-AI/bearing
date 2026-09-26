# MCP server sketch, Python (FastMCP from the `mcp` package)

`uv add "mcp[cli]" pydantic structlog`. Layout: `mcp_server/server.py`
(tools), `mcp_server/backend.py` (the calls to the real system),
`tests/test_mcp_tools.py`. Logs to stderr; stdout carries the protocol.

```python
import os, sys, time, uuid
from typing import Literal
import structlog
from pydantic import BaseModel, Field
from mcp.server.fastmcp import FastMCP, Context
from mcp.types import ToolAnnotations

structlog.configure(logger_factory=structlog.PrintLoggerFactory(file=sys.stderr))
log = structlog.get_logger()

mcp = FastMCP("orders")                      # one server per bounded context

class ListOrdersIn(BaseModel):
    customer_id: str = Field(description="Customer id from find_customer, never an email", max_length=64)
    limit: int = Field(20, ge=1, le=20, description="Maximum orders to return")
    cursor: str | None = Field(None, description="Opaque cursor from a previous call")

class ToolError(BaseModel):
    code: Literal["not_found", "invalid_input", "rate_limited", "backend_unavailable"]
    message: str
    retryable: bool

def _request_id(ctx: Context | None) -> str:
    return (ctx.request_id if ctx and ctx.request_id else uuid.uuid4().hex)

# Tier read: every hint set explicitly; an unset hint is the worst case to the host.
@mcp.tool(title="List orders", annotations=ToolAnnotations(
    readOnlyHint=True, destructiveHint=False, idempotentHint=True, openWorldHint=False))
async def list_orders(params: ListOrdersIn, ctx: Context) -> dict:
    """Returns up to 20 orders for a customer id, newest first, totals in INR paise, with next_cursor.

    Use it to answer questions about a customer's orders. Do not use it to find a
    customer; use find_customer. Errors: not_found for an unknown customer_id,
    rate_limited when the caller exceeds 60 calls a minute.
    """
    rid, started = _request_id(ctx), time.monotonic()
    try:
        if not await rate_limiter.allow(caller_of(ctx)):
            return ToolError(code="rate_limited", message="60 calls per minute", retryable=True).model_dump()
        page = await backend.list_orders(params.customer_id, params.limit, params.cursor, timeout=30)
        if page is None:
            return ToolError(code="not_found", message=f"customer {params.customer_id} does not exist", retryable=False).model_dump()
        return {"items": [redact(o) for o in page.items], "next_cursor": page.next_cursor}
    finally:
        log.info("tool.call", request_id=rid, tool="list_orders", ms=int((time.monotonic() - started) * 1000))

@mcp.resource("resource://orders/{order_id}")
async def order_document(order_id: str) -> str:
    """The full order document as JSON, read-only."""
    ...

@mcp.prompt()
def triage_order(order_id: str) -> str:
    """Recipe: summarise an order's state and the next action."""
    return prompts.render(prompts.load("triage_order", 1), {"order_id": order_id})

if __name__ == "__main__":
    transport = os.environ.get("MCP_TRANSPORT", "stdio")     # stdio | streamable-http
    mcp.run(transport=transport)
```

Streamable HTTP with a bearer check: run with `MCP_TRANSPORT=streamable-http`
and mount the FastMCP ASGI app behind a middleware that rejects a
request whose `Authorization: Bearer <token>` does not match
`MCP_BEARER_TOKEN` (constant-time compare). OAuth for user-scoped
servers per the `mcp` package's auth docs; never hand-roll it.

## Test through the protocol

The counts come from this test. It prints one line before it asserts,
so a failing run still shows the numbers (run with `uv run pytest -s`):

```
mcp-tools: N exposed, N tested, N annotated
```

A tool is tested when `CASES` holds its valid, invalid and not-found
calls; annotated when all four hints are set and the read-only and
destructive hints match its tier. It fails on zero tools exposed, when
the three counts differ, or when `CASES` names a tool the server does
not list.

```python
import pytest
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

CASES = {  # every tool: valid, invalid, not found
    "list_orders": [({"params": {"customer_id": "c_1"}}, "items"),
                    ({"params": {"customer_id": "c_1", "limit": 0}}, "error"),
                    ({"params": {"customer_id": "nope"}}, "not_found")],
}
TIERS = {"list_orders": "read"}  # the same tiers as mcp/tiers.yaml
HINTS = {  # tier -> (readOnlyHint, destructiveHint); idempotent and openWorld must be set
    "read": (True, False), "write": (False, False), "irreversible": (False, True),
}

@pytest.mark.asyncio
async def test_every_tool_through_the_protocol():
    server = StdioServerParameters(command="uv", args=["run", "python", "-m", "mcp_server.server"], env={"BACKEND": "fake"})
    async with stdio_client(server) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            listed = (await session.list_tools()).tools
            tools = {t.name for t in listed}
            tested = {n for n in tools if len(CASES.get(n, [])) >= 3}

            def annotated(t):  # all four hints set, and the two that carry the tier match it
                a = t.annotations
                return (a is not None and t.name in TIERS
                        and None not in (a.readOnlyHint, a.destructiveHint, a.idempotentHint, a.openWorldHint)
                        and (a.readOnlyHint, a.destructiveHint) == HINTS[TIERS[t.name]])

            n_annotated = sum(annotated(t) for t in listed)
            print(f"mcp-tools: {len(tools)} exposed, {len(tested)} tested, {n_annotated} annotated")
            assert tools, "0 tools exposed"
            assert len(tools) == len(tested) == n_annotated, (
                f"untested: {sorted(tools - tested)}; not annotated to tier: "
                f"{sorted(t.name for t in listed if not annotated(t))}")
            assert set(CASES) <= tools, f"CASES names tools the server does not list: {set(CASES) - tools}"
            for name, cases in CASES.items():
                for args, expect in cases:
                    result = await session.call_tool(name, arguments=args)
                    assert expect in result.content[0].text
```

## Makefile

```
mcp-dev: ## Open the MCP inspector on the stdio server
	npx @modelcontextprotocol/inspector uv run python -m mcp_server.server
```
