# Agent sketch, Python (Anthropic SDK 1.x, tool runner)

A sketch of the pieces, not a drop-in. Verify the runner hooks against
the SDK's own `tools.md` (the `claude-api` skill lists the repository).
Python 3.12, `uv add anthropic`, FastAPI service around it, structlog
for the log lines, the prompt from the registry (`prompt-registry`).

```python
import functools, json, os, time
from dataclasses import dataclass
import anthropic
from anthropic import beta_tool
import structlog

from app import prompts
from app.agents.registry import REGISTRY, ToolMeta       # tool-registry.md
from app.guardrails import check_input, check_output, gate_tool   # llm-guardrails
from app.llm.gateway import cost_usd, kill_switch_tripped        # llm-gateway

log = structlog.get_logger()

@dataclass(frozen=True)
class Bounds:
    max_turns: int = 10
    max_cost_usd: float = 0.50
    call_timeout_s: float = 60.0
    wall_clock_s: float = 300.0

def gated(meta: ToolMeta, request_id: str):
    """Wrap a tool handler with the tier gate, the timeout and the log line."""
    def wrap(fn):
        @functools.wraps(fn)
        def inner(**kwargs):
            started = time.monotonic()
            verdict = gate_tool(meta, kwargs)                 # read | write | irreversible
            if not verdict.allowed:
                log.info("tool.denied", request_id=request_id, tool=meta.name, tier=meta.tier, reason=verdict.reason)
                return json.dumps({"error": verdict.reason, "tool": meta.name})
            try:
                out = fn(**kwargs)                            # the handler enforces meta.timeout_s itself
                outcome = "ok"
            except Exception as e:                            # the loop never sees a raise
                out, outcome = json.dumps({"error": type(e).__name__}), "error"
            log.info("tool.call", request_id=request_id, tool=meta.name, tier=meta.tier,
                     outcome=outcome, ms=int((time.monotonic() - started) * 1000))
            return out
        return inner
    return wrap

@beta_tool
def list_orders(customer_id: str, limit: int = 20) -> str:
    """Return up to `limit` orders for a customer id, newest first, totals in INR paise.

    Args:
        customer_id: The customer's id from find_customer, never an email.
        limit: 1 to 20.
    """
    ...

TOOLS = (list_orders,)   # every tool sent to the model; the registry test reads this tuple

def run(task: str, request_id: str, bounds: Bounds = Bounds()) -> str:
    if os.environ.get("AGENT_KILL_SWITCH") == "1" or kill_switch_tripped("orders-agent"):
        log.warning("agent.killed", request_id=request_id, reason="switch")
        return "unavailable"
    check_input(task)                                         # raises GuardrailError

    p = prompts.load("orders_agent", 2)
    tools = [gated(REGISTRY[f.name], request_id)(f) for f in TOOLS]
    assert {t.name for t in tools} == set(REGISTRY), "registry and tools differ"

    client = anthropic.Anthropic(timeout=bounds.call_timeout_s)
    runner = client.beta.messages.tool_runner(
        model=p.model,                                        # claude-opus-5 by default
        max_tokens=p.max_tokens,
        output_config={"effort": p.effort},
        system=[{"type": "text", "text": prompts.render(p, {}), "cache_control": {"type": "ephemeral"}}],
        tools=tools,
        messages=[{"role": "user", "content": task}],
        max_iterations=bounds.max_turns,
    )
    spent, started, final = 0.0, time.monotonic(), None
    for turn, message in enumerate(runner, start=1):
        spent += cost_usd(p.model, message.usage)
        log.info("model.call", request_id=request_id, agent="orders-agent", turn=turn, model=p.model,
                 tokens_in=message.usage.input_tokens, tokens_out=message.usage.output_tokens,
                 cache_read=message.usage.cache_read_input_tokens, cost_usd=round(spent, 4),
                 stop=message.stop_reason)
        final = message
        if message.stop_reason == "refusal":
            log.warning("agent.refusal", request_id=request_id, details=message.stop_details); break
        if spent > bounds.max_cost_usd or time.monotonic() - started > bounds.wall_clock_s:
            log.warning("agent.bounded", request_id=request_id, cost_usd=spent); break
        if kill_switch_tripped("orders-agent"):
            log.warning("agent.killed", request_id=request_id, reason="switch"); break
    text = "".join(b.text for b in (final.content if final else []) if b.type == "text")
    return check_output(text)                                 # schema, PII leak, policy
```

Notes:

- `max_iterations` bounds turns; money is bounded from `usage` because
  one turn can carry a large tool result.
- `stop_reason == "max_tokens"` on a turn: raise `max_tokens` once and
  retry that turn; twice is a failure to log.
- A `pause_turn` (server tools) is not resumed by the Python runner;
  mirror the history and restart the runner with the paused turn, or
  keep server tools out of this agent.
- Fable 5.1: omit `thinking`, keep `tool_choice` at `auto`, add the
  `fallbacks` parameter as the `claude-api` skill shows, and stream.
- Parallel tool calls in one turn come back as one user message; the
  runner does that. A manual loop must too.
- Memory: keep the last N turns; beyond that, server-side compaction
  (`compact-2026-01-12` beta) or a summariser call on Sonnet 5.
- Registry test: `tests/agents/test_registry.py` from `tool-registry.md`
  prints the `agent-tools:` counts line and fails on zero tools or a
  mismatch; run it with `uv run pytest -s` so the line is shown.
- Tests: handler unit tests; `gate_tool` denies `irreversible` without
  approval; the loop stops at `max_cost_usd` with a fake client that
  returns a large `usage`; the kill switch stops before the first call.
- Eval: `evals/orders-agent/trajectories.jsonl`, one line per case
  with `input`, `expected_tools` (ordered), `expected_outcome`; run by
  `llm-eval`.
