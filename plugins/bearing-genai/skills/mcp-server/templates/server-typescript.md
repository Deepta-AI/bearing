# MCP server sketch, TypeScript (`@modelcontextprotocol/sdk`, Node 24)

`npm i @modelcontextprotocol/sdk zod express pino`. Layout:
`src/mcp/server.ts` (tools), `src/mcp/backend.ts`, `src/mcp/main.ts`
(transport), `src/mcp/server.test.ts`. Logs to stderr on stdio.

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express from "express";
import { randomUUID, timingSafeEqual } from "node:crypto";
import pino from "pino";
import { z } from "zod";

const log = pino(pino.destination(2));                          // stderr; stdout is the protocol

export const server = new McpServer({ name: "orders", version: "1.0.0" });

const toolError = (code: "not_found" | "invalid_input" | "rate_limited" | "backend_unavailable", message: string, retryable: boolean) =>
  ({ content: [{ type: "text" as const, text: JSON.stringify({ code, message, retryable }) }], isError: true });

server.registerTool(
  "list_orders",
  {
    title: "List orders",
    // Tier read: every hint set explicitly; an unset hint is the worst case to the host.
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    description:
      "Returns up to 20 orders for a customer id, newest first, totals in INR paise, with next_cursor. " +
      "Use it to answer questions about a customer's orders. Do not use it to find a customer; use find_customer. " +
      "Errors: not_found for an unknown customer_id, rate_limited above 60 calls a minute.",
    inputSchema: {
      customer_id: z.string().max(64).describe("Customer id from find_customer, never an email"),
      limit: z.number().int().min(1).max(20).default(20).describe("Maximum orders to return"),
      cursor: z.string().optional().describe("Opaque cursor from a previous call"),
    },
  },
  async ({ customer_id, limit, cursor }, extra) => {
    const requestId = String(extra.requestId ?? randomUUID());
    const started = Date.now();
    try {
      if (!(await rateLimiter.allow(callerOf(extra)))) return toolError("rate_limited", "60 calls per minute", true);
      const page = await backend.listOrders(customer_id, limit, cursor, { timeoutMs: 30_000 });
      if (!page) return toolError("not_found", `customer ${customer_id} does not exist`, false);
      return { content: [{ type: "text", text: JSON.stringify({ items: page.items.map(redact), next_cursor: page.nextCursor }) }] };
    } finally {
      log.info({ requestId, tool: "list_orders", ms: Date.now() - started }, "tool.call");
    }
  },
);

server.registerResource("order", "resource://orders/{order_id}", { description: "The full order document, read-only" },
  async (uri) => ({ contents: [{ uri: uri.href, text: await backend.orderJson(uri.pathname) }] }));

server.registerPrompt("triage_order", { description: "Summarise an order's state and the next action", argsSchema: { order_id: z.string() } },
  ({ order_id }) => ({ messages: [{ role: "user", content: { type: "text", text: render(load("triage_order", 1), { order_id }) } }] }));

export async function main() {
  if (process.env.MCP_TRANSPORT === "streamable-http") {
    const app = express(); app.use(express.json());
    app.all("/mcp", async (req, res) => {
      const given = Buffer.from(req.header("authorization")?.replace(/^Bearer /, "") ?? "");
      const want = Buffer.from(process.env.MCP_BEARER_TOKEN ?? "");
      if (given.length !== want.length || !timingSafeEqual(given, want)) return res.status(401).end();
      const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
      await server.connect(transport);
      await transport.handleRequest(req, res, req.body);
    });
    app.get("/healthz", (_req, res) => res.json({ ok: true }));
    app.listen(Number(process.env.PORT ?? 3333));
  } else {
    await server.connect(new StdioServerTransport());
  }
}
```

## Test through the protocol (vitest)

The counts come from this test; it prints one line before it asserts:

```
mcp-tools: N exposed, N tested, N annotated
```

A tool is tested when `CASES` holds its valid, invalid and not-found
calls; annotated when all four hints are booleans and the read-only and
destructive hints match its tier. It fails on zero tools exposed, when
the three counts differ, or when `CASES` names a tool the server does
not list.

```typescript
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const CASES: Record<string, Array<[Record<string, unknown>, string]>> = {
  list_orders: [[{ customer_id: "c_1" }, "items"], [{ customer_id: "c_1", limit: 0 }, "invalid"], [{ customer_id: "nope" }, "not_found"]],
};
const TIERS: Record<string, "read" | "write" | "irreversible"> = { list_orders: "read" }; // as in mcp/tiers.yaml
const HINTS = { read: [true, false], write: [false, false], irreversible: [false, true] } as const; // readOnly, destructive

it("calls every tool through the protocol", async () => {
  const client = new Client({ name: "test", version: "0" });
  await client.connect(new StdioClientTransport({ command: "node", args: ["dist/mcp/main.js"], env: { ...process.env, BACKEND: "fake" } }));
  const listed = (await client.listTools()).tools;
  const tools = listed.map((t) => t.name);
  const tested = tools.filter((n) => (CASES[n] ?? []).length >= 3);
  const annotated = (t: (typeof listed)[number]) => {    // all four hints set, the tier's two match
    const a = t.annotations; const tier = TIERS[t.name];
    return !!a && !!tier
      && (["readOnlyHint", "destructiveHint", "idempotentHint", "openWorldHint"] as const).every((h) => typeof a[h] === "boolean")
      && a.readOnlyHint === HINTS[tier][0] && a.destructiveHint === HINTS[tier][1];
  };
  const nAnnotated = listed.filter(annotated).length;
  console.log(`mcp-tools: ${tools.length} exposed, ${tested.length} tested, ${nAnnotated} annotated`);
  expect(tools.length, "0 tools exposed").toBeGreaterThan(0);
  expect([tested.length, nAnnotated], `untested or not annotated to tier`).toEqual([tools.length, tools.length]);
  expect(Object.keys(CASES).filter((n) => !tools.includes(n)), "CASES names tools the server does not list").toEqual([]);
  for (const [name, cases] of Object.entries(CASES))
    for (const [args, expected] of cases) {
      const r = await client.callTool({ name, arguments: args });
      expect(JSON.stringify(r.content)).toContain(expected);
    }
  await client.close();
});
```

## Makefile

```
mcp-dev: ## Open the MCP inspector on the stdio server
	npx @modelcontextprotocol/inspector@2.8.0 node dist/mcp/main.js
```
