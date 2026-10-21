# Tool registry

One registry per agent. Every tool the model can call is an entry here;
nothing else is passed to the SDK. The registry is data the tests read:
the count of entries equals the count of tools sent to the model, and
every entry has a schema and a tier.

## Entry shape

| Field | Rule |
| --- | --- |
| `name` | `verb_object`, snake_case, unique per agent, under 40 chars |
| `description` | written for the model: what it returns, when to use it, when not to, units and limits. Two to four sentences. |
| `input_schema` | JSON Schema, `additionalProperties: false`, every property described, `required` listed; sent with `strict: true` |
| `tier` | `read` (no side effect), `write` (reversible change, idempotent by a key), `irreversible` (money, messages, deletes, external calls with effects) |
| `timeout_s` | per call; the handler is cancelled past it and returns `is_error` |
| `idempotent` | true when calling twice with the same input has the same effect; required true for `write` in a `background` agent |
| `handler` | the function; validates its input again (the schema is a contract, not a guard), never raises to the loop, returns a string or a JSON string |

## Tier rules

- `read`: runs without a gate. May run in parallel with other `read`
  calls in the same turn.
- `write`: runs after argument validation against the policy in
  `guardrails/policy.yaml` (denylist of paths, ids, amounts). Logged
  with the key it wrote.
- `irreversible`: in a `human-in-the-loop` agent the handler returns
  `{"status": "approval_required", "approval_id": ...}` and the run
  suspends; on approval the same call is replayed with the id. In every
  other type the gate denies the call and the model is told so in the
  tool result; the denial is a metric.
- A tool with no tier is `irreversible`. The test that counts tiers
  fails on a missing one.

## Descriptions the model can use

Bad: "Searches orders."
Good: "Returns up to 20 orders for a customer id, newest first, with
status and total in INR paise. Use it to answer questions about a
customer's orders. Do not use it to find a customer; use
`find_customer` for that. Fails with `not_found` for an unknown id."

## Sketch (Python)

```python
from dataclasses import dataclass
from typing import Callable, Literal

Tier = Literal["read", "write", "irreversible"]

@dataclass(frozen=True)
class ToolMeta:
    name: str
    tier: Tier
    timeout_s: float
    idempotent: bool

REGISTRY: dict[str, ToolMeta] = {
    "find_customer": ToolMeta("find_customer", "read", 10, True),
    "list_orders":   ToolMeta("list_orders", "read", 10, True),
    "issue_refund":  ToolMeta("issue_refund", "irreversible", 30, True),
}
```

The typed tool functions (see `agent-python.md`) are decorated with
`@beta_tool`, which builds the schema from the signature and docstring;
the test asserts every function name in the tools list is in
`REGISTRY` and vice versa.

## Sketch (TypeScript)

```typescript
export type Tier = "read" | "write" | "irreversible";
export interface ToolMeta { name: string; tier: Tier; timeoutMs: number; idempotent: boolean }

export const REGISTRY: Record<string, ToolMeta> = {
  find_customer: { name: "find_customer", tier: "read", timeoutMs: 10_000, idempotent: true },
  list_orders:   { name: "list_orders",   tier: "read", timeoutMs: 10_000, idempotent: true },
  issue_refund:  { name: "issue_refund",  tier: "irreversible", timeoutMs: 30_000, idempotent: true },
};
```

## Test

The counts come from this test, never from the report. It prints one
line before it asserts, so a failing run still shows the numbers:

```
agent-tools: N sent to the model, N registry entries, N with a schema, tiers read N, write N, irreversible N, missing 0
```

and fails on zero tools (an agent with no tools is a prompt), when the
three counts differ, when the names sent and the registry's names
differ, or on a tool with no tier. A schema counts when it is an
`object` whose every property has a description and whose `required`
list names only its own properties.

Python, `tests/agents/test_registry.py` (run with `uv run pytest -s`):

```python
from app.agents.orders import TOOLS          # the tuple of @beta_tool functions the agent sends
from app.agents.registry import REGISTRY

TIERS = ("read", "write", "irreversible")

def has_schema(p: dict) -> bool:
    s = p.get("input_schema") or {}
    props = s.get("properties")
    return (s.get("type") == "object" and isinstance(props, dict)
            and all(isinstance(v, dict) and v.get("description") for v in props.values())
            and set(s.get("required", [])) <= set(props))

def test_registry_counts():
    params = [t.to_dict() for t in TOOLS]    # exactly what the SDK sends: name, description, input_schema
    sent = {p["name"] for p in params}
    with_schema = sum(has_schema(p) for p in params)
    tiers = {t: sum(m.tier == t for m in REGISTRY.values()) for t in TIERS}
    missing = sum(getattr(m, "tier", None) not in TIERS for m in REGISTRY.values())
    print(f"agent-tools: {len(params)} sent to the model, {len(REGISTRY)} registry entries, "
          f"{with_schema} with a schema, tiers read {tiers['read']}, write {tiers['write']}, "
          f"irreversible {tiers['irreversible']}, missing {missing}")
    assert params, "0 tools sent to the model: an agent with no tools is a prompt"
    assert len(params) == len(REGISTRY) == with_schema, "sent, registry and schema counts differ"
    assert sent == set(REGISTRY), f"sent but unregistered: {sent - set(REGISTRY)}; registered but not sent: {set(REGISTRY) - sent}"
    assert missing == 0, "a tool without a tier is irreversible until someone says otherwise; set it"
```

TypeScript, `src/agents/registry.test.ts` (vitest prints the line):

```typescript
import { expect, it } from "vitest";
import { toolsFor } from "./orders.js";       // the tools the agent sends
import { REGISTRY } from "./registry.js";

const TIERS = ["read", "write", "irreversible"] as const;

function hasSchema(t: { input_schema?: { type?: string; properties?: Record<string, { description?: string }>; required?: string[] } }) {
  const s = t.input_schema; const props = s?.properties;
  return s?.type === "object" && !!props && Object.values(props).every((v) => !!v?.description)
    && (s.required ?? []).every((r) => r in props);
}

it("registry counts", () => {
  const tools = toolsFor("test");
  const sent = new Set(tools.map((t) => t.name));
  const withSchema = tools.filter(hasSchema).length;
  const entries = Object.values(REGISTRY);
  const tiers = Object.fromEntries(TIERS.map((t) => [t, entries.filter((m) => m.tier === t).length]));
  const missing = entries.filter((m) => !TIERS.includes(m.tier)).length;
  console.log(`agent-tools: ${tools.length} sent to the model, ${entries.length} registry entries, ${withSchema} with a schema, ` +
    `tiers read ${tiers.read}, write ${tiers.write}, irreversible ${tiers.irreversible}, missing ${missing}`);
  expect(tools.length, "0 tools sent to the model").toBeGreaterThan(0);
  expect([entries.length, withSchema], "sent, registry and schema counts differ").toEqual([tools.length, tools.length]);
  expect(sent).toEqual(new Set(Object.keys(REGISTRY)));
  expect(missing, "a tool without a tier").toBe(0);
});
```
