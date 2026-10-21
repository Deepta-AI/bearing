# MCP client sketch: connect an agent to servers

The client discovers tools and maps them into the agent's registry
(`llm-agent`, `tool-registry.md`) with a permission tier from
`mcp/tiers.yaml`. Unmapped tools are `irreversible` and reported.
Configuration in `mcp/servers.yaml` (command or url, env var names).

```yaml
# mcp/tiers.yaml
orders:
  list_orders: read
  get_invoice: read
  create_ticket: write
  issue_refund: irreversible
```

## Python (`app/mcp/client.py`)

```python
import asyncio, json, time, uuid
from contextlib import AsyncExitStack
import structlog, yaml
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from mcp.client.streamable_http import streamablehttp_client
from app.agents.registry import ToolMeta

log = structlog.get_logger()
BACKOFF = (1, 2, 4, 8, 16, 30)

class McpClient:
    def __init__(self, servers: dict, tiers: dict):
        self.servers, self.tiers, self.sessions, self.registry = servers, tiers, {}, {}

    async def connect(self, name: str) -> None:
        cfg, stack = self.servers[name], AsyncExitStack()
        for delay in BACKOFF:
            try:
                if "url" in cfg:
                    read, write, _ = await stack.enter_async_context(streamablehttp_client(cfg["url"], headers=cfg.get("headers")))
                else:
                    read, write = await stack.enter_async_context(stdio_client(StdioServerParameters(command=cfg["command"], args=cfg.get("args", []))))
                session = await stack.enter_async_context(ClientSession(read, write))
                await session.initialize()
                self.sessions[name] = (session, stack)
                await self.discover(name)
                return
            except Exception as e:
                log.warning("mcp.connect_failed", server=name, error=type(e).__name__, retry_in=delay)
                await asyncio.sleep(delay)
        log.error("mcp.unavailable", server=name)          # the agent runs without this server's tools

    async def discover(self, name: str) -> None:
        session, _ = self.sessions[name]
        tools = (await session.list_tools()).tools
        mapped = self.tiers.get(name, {})
        for t in tools:
            tier = mapped.get(t.name, "irreversible")
            if t.name not in mapped:
                log.warning("mcp.unmapped_tool", server=name, tool=t.name, tier=tier)
            self.registry[f"{name}__{t.name}"] = (ToolMeta(f"{name}__{t.name}", tier, 30, False), t)
        log.info("mcp.discovered", server=name, tools=len(tools), mapped=sum(t.name in mapped for t in tools))

    async def call(self, qualified: str, arguments: dict, request_id: str | None = None) -> str:
        request_id = request_id or uuid.uuid4().hex
        server, tool = qualified.split("__", 1)
        session, _ = self.sessions[server]
        started = time.monotonic()
        try:
            result = await asyncio.wait_for(session.call_tool(tool, arguments=arguments), timeout=30)
            text = "".join(c.text for c in result.content if getattr(c, "text", None))
            return text if not result.isError else json.dumps({"error": text})
        except asyncio.TimeoutError:
            return json.dumps({"error": "timeout", "tool": qualified})
        finally:
            log.info("mcp.call", request_id=request_id, tool=qualified, ms=int((time.monotonic() - started) * 1000))
```

Handling `notifications/tools/list_changed`: register a handler on the
session (the `mcp` package exposes a callback on `ClientSession`) that
calls `discover(name)` again and removes registry entries no longer
listed. Feed the registry into the agent with the SDK's MCP helpers
(`anthropic.lib.tools.mcp.async_mcp_tool`) or by building tool
definitions from `t.inputSchema` and routing calls through `call`.

## TypeScript (`src/mcp/client.ts`)

```typescript
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import type { ToolMeta } from "../agents/registry.js";

export class McpClient {
  readonly registry = new Map<string, { meta: ToolMeta; schema: unknown }>();
  private clients = new Map<string, Client>();
  constructor(private servers: Record<string, { command?: string; args?: string[]; url?: string }>,
              private tiers: Record<string, Record<string, ToolMeta["tier"]>>) {}

  async connect(name: string): Promise<void> {
    const cfg = this.servers[name];
    for (const delay of [1, 2, 4, 8, 16, 30]) {
      try {
        const client = new Client({ name: "agent", version: "1" });
        await client.connect(cfg.url ? new StreamableHTTPClientTransport(new URL(cfg.url))
                                     : new StdioClientTransport({ command: cfg.command!, args: cfg.args ?? [] }));
        client.setNotificationHandler(ToolListChangedNotificationSchema, () => this.discover(name));
        this.clients.set(name, client);
        await this.discover(name);
        return;
      } catch (e) { await new Promise((r) => setTimeout(r, delay * 1000)); }
    }
    log.error({ server: name }, "mcp.unavailable");
  }

  async discover(name: string): Promise<void> {
    const { tools } = await this.clients.get(name)!.listTools();
    for (const key of [...this.registry.keys()]) if (key.startsWith(`${name}__`)) this.registry.delete(key);
    for (const t of tools) {
      const tier = this.tiers[name]?.[t.name] ?? "irreversible";
      if (!this.tiers[name]?.[t.name]) log.warn({ server: name, tool: t.name }, "mcp.unmapped_tool");
      this.registry.set(`${name}__${t.name}`, { meta: { name: `${name}__${t.name}`, tier, timeoutMs: 30_000, idempotent: false }, schema: t.inputSchema });
    }
  }

  async call(qualified: string, args: Record<string, unknown>, requestId: string): Promise<string> {
    const [server, tool] = qualified.split("__", 2);
    const started = Date.now();
    try {
      const r = await Promise.race([this.clients.get(server)!.callTool({ name: tool, arguments: args }), timeout(30_000)]);
      const text = JSON.stringify(r.content);
      return r.isError ? JSON.stringify({ error: text }) : text;
    } catch { return JSON.stringify({ error: "timeout", tool: qualified }); }
    finally { log.info({ requestId, tool: qualified, ms: Date.now() - started }, "mcp.call"); }
  }
}
```

`ToolListChangedNotificationSchema` comes from
`@modelcontextprotocol/sdk/types.js`. Map each registry entry to a
`betaTool()` (raw JSON schema from `t.inputSchema`) whose `run` calls
`client.call`, gated by tier as in `agent-typescript.md`.

## Fake server for tests

Start a FastMCP or McpServer instance in the test with `alpha`
(mapped `read`) and `beta` (unmapped) over stdio. Assert: two tools
discovered, `beta` is `irreversible`, killing and restarting the
process reconnects, a `list_changed` after registering `gamma` adds it
as `irreversible`, and a tool that sleeps past the timeout returns the
`timeout` error. Print `servers 1, tools 2, mapped 1, unmapped 1`.
