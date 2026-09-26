# Guardrails fixture test

The counts in the report come from this test, never from the model. It
prints one line before it asserts, so a failing run still shows them:

```
guardrails: C checks configured (input a, tool b, output c), F fixtures, P passing, K policy keys without a fixture
```

and fails when C or F is zero, when P differs from F, or when K is
above zero.

Contract with the module (`app/guardrails/` or `src/guardrails/`):

- `CHECKS`: a mapping from a check name to a function that takes the
  fixture's `input` and returns a verdict with a `verdict` field
  (`allowed`, `redacted`, `blocked`, `denied`, `pii_leak`,
  `prompt_leak`, `schema_invalid`, `ungrounded`, `refused`,
  `policy: disallowed`). The name is `<stage>.<policy key>`: stage
  `input`, `tool` or `output`; key a top-level section of
  `policy.yaml` (`limits`, `pii`, `injection`, `tools`) or a key under
  `output` (`schema_required`, `pii_leak`, `prompt_leak`, `classifier`,
  `grounding`, `refusal`). So `input.pii`, `tool.tools`,
  `output.grounding`.
- `POLICY`: the loaded `policy.yaml`, as the module read it at start.

Fixtures: `tests/guardrails/fixtures.jsonl`, one JSON object per line,
`{id, check, input, expected, note}`, from
`references/adversarial-set.md`; `check` is a `CHECKS` name.

## Python, `tests/guardrails/test_fixtures.py` (run with `uv run pytest -s`)

```python
import json
import pathlib

import pytest

from app.guardrails import CHECKS, POLICY

FIXTURES = [
    json.loads(line)
    for line in pathlib.Path(__file__).with_name("fixtures.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
POLICY_KEYS = [k for k in POLICY if k not in ("version", "owner", "metrics", "output")] + list(POLICY.get("output", {}))


def verdict(f):
    check = CHECKS.get(f["check"])
    return check(f["input"]).verdict if check else f"unknown check {f['check']}"


@pytest.mark.parametrize("f", FIXTURES, ids=[f["id"] for f in FIXTURES])
def test_fixture(f):
    assert verdict(f) == f["expected"], f.get("note", "")


def test_counts():
    passing = sum(verdict(f) == f["expected"] for f in FIXTURES)
    stage = {s: sum(k.startswith(s + ".") for k in CHECKS) for s in ("input", "tool", "output")}
    exercised = {f["check"].split(".", 1)[-1] for f in FIXTURES}
    unexercised = [k for k in POLICY_KEYS if k not in exercised]
    print(
        f"guardrails: {len(CHECKS)} checks configured (input {stage['input']}, tool {stage['tool']}, "
        f"output {stage['output']}), {len(FIXTURES)} fixtures, {passing} passing, "
        f"{len(unexercised)} policy keys without a fixture"
    )
    assert CHECKS, "0 checks configured"
    assert FIXTURES, "0 fixtures: the proof is empty"
    assert passing == len(FIXTURES), "a fixture the module does not catch"
    assert not unexercised, f"policy keys without a fixture: {unexercised}"
```

## TypeScript, `src/guardrails/fixtures.test.ts` (vitest prints the line)

```typescript
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { CHECKS, POLICY } from "./index.js";

type Fixture = { id: string; check: string; input: unknown; expected: string; note?: string };
const FIXTURES: Fixture[] = readFileSync(new URL("../../tests/guardrails/fixtures.jsonl", import.meta.url), "utf8")
  .split("\n").filter((l) => l.trim()).map((l) => JSON.parse(l));
const POLICY_KEYS = [
  ...Object.keys(POLICY).filter((k) => !["version", "owner", "metrics", "output"].includes(k)),
  ...Object.keys(POLICY.output ?? {}),
];
const verdict = (f: Fixture) => (CHECKS[f.check] ? CHECKS[f.check](f.input).verdict : `unknown check ${f.check}`);

describe("guardrail fixtures", () => {
  it.each(FIXTURES.map((f) => [f.id, f] as const))("%s", (_id, f) => {
    expect(verdict(f), f.note).toBe(f.expected);
  });

  it("counts", () => {
    const passing = FIXTURES.filter((f) => verdict(f) === f.expected).length;
    const stage = (s: string) => Object.keys(CHECKS).filter((k) => k.startsWith(`${s}.`)).length;
    const exercised = new Set(FIXTURES.map((f) => f.check.split(".").slice(1).join(".") || f.check));
    const unexercised = POLICY_KEYS.filter((k) => !exercised.has(k));
    console.log(`guardrails: ${Object.keys(CHECKS).length} checks configured (input ${stage("input")}, tool ${stage("tool")}, ` +
      `output ${stage("output")}), ${FIXTURES.length} fixtures, ${passing} passing, ${unexercised.length} policy keys without a fixture`);
    expect(Object.keys(CHECKS).length, "0 checks configured").toBeGreaterThan(0);
    expect(FIXTURES.length, "0 fixtures: the proof is empty").toBeGreaterThan(0);
    expect(passing, "a fixture the module does not catch").toBe(FIXTURES.length);
    expect(unexercised, "policy keys without a fixture").toEqual([]);
  });
});
```

`it.each` over an empty list registers no case, which is why the
`counts` test asserts the fixture count itself.
