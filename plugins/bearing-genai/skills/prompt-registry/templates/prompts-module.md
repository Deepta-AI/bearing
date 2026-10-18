# The prompts module, one per stack

Sketches, not drop-ins. The module reads `prompts/<name>/v<N>.md`,
validates the variables, substitutes `{{name}}` with a strict regex, and
returns the text with the frontmatter so the caller takes `model`,
`effort` and `max_tokens` from the prompt.

## Python (`app/prompts/__init__.py`)

```python
import re
from dataclasses import dataclass
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[2] / "prompts"
PLACEHOLDER = re.compile(r"\{\{([a-z_][a-z0-9_]*)\}\}")

@dataclass(frozen=True)
class Prompt:
    name: str
    version: int
    model: str
    effort: str
    max_tokens: int
    variables: list[dict]
    body: str

class PromptError(ValueError):
    """A prompt failed to load or render. Raised before any model call."""

def load(name: str, version: int) -> Prompt:
    path = ROOT / name / f"v{version}.md"
    if not path.exists():
        raise PromptError(f"no prompt {name} v{version} at {path}")
    text = path.read_text(encoding="utf-8")
    _, front, body = text.split("---", 2)
    meta = yaml.safe_load(front)
    return Prompt(name, meta["version"], meta["model"], meta["effort"],
                  meta["max_tokens"], meta["variables"], body.strip())

def render(prompt: Prompt, values: dict[str, str]) -> str:
    spec = {v["name"]: v for v in prompt.variables}
    unknown = set(values) - set(spec)
    missing = {n for n, v in spec.items() if v.get("required") and n not in values}
    if unknown or missing:
        raise PromptError(f"{prompt.name}: unknown {sorted(unknown)}, missing {sorted(missing)}")
    for n, val in values.items():
        limit = spec[n].get("max_chars")
        if limit and len(val) > limit:
            raise PromptError(f"{prompt.name}: {n} is {len(val)} chars, limit {limit}")
        allowed = spec[n].get("enum")
        if allowed and val not in allowed:
            raise PromptError(f"{prompt.name}: {n}={val!r} not in {allowed}")
        values[n] = val.replace(f"</{n}>", f"<\\/{n}>")
    out = PLACEHOLDER.sub(lambda m: values.get(m.group(1), ""), prompt.body)
    if PLACEHOLDER.search(out):
        raise PromptError(f"{prompt.name}: unfilled placeholder")
    return out
```

Call site (the system text is the stable prefix, so it carries the
cache breakpoint; the volatile input goes in the user turn):

```python
import anthropic
from app import prompts

client = anthropic.Anthropic()
p = prompts.load("invoice_extract", 3)
system = prompts.render(p, {"locale": "en-IN"})
response = client.messages.parse(
    model=p.model,
    max_tokens=p.max_tokens,
    output_config={"effort": p.effort},
    system=[{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
    messages=[{"role": "user", "content": f"<input_text>\n{text}\n</input_text>"}],
    output_format=InvoiceFields,   # a Pydantic model; the same schema as the prompt
)
```

Test (`tests/test_prompts.py`): iterate `prompts/*/v*.md`, load each,
render with `fixtures.json`, assert no placeholder remains and every
declared variable appears in the body; assert `render` raises on an
oversized and an unknown variable; print `N prompts rendered`; fail on
zero.

## TypeScript (`src/prompts/index.ts`)

```typescript
import { readFileSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parse } from "yaml";
import { z } from "zod";

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, "../../prompts");
const PLACEHOLDER = /\{\{([a-z_][a-z0-9_]*)\}\}/g;

const Variable = z.object({
  name: z.string(), type: z.literal("string"), required: z.boolean().default(false),
  max_chars: z.number().int().optional(), enum: z.array(z.string()).optional(),
});
const Front = z.object({
  name: z.string(), version: z.number().int(), model: z.string(),
  effort: z.enum(["low", "medium", "high", "xhigh", "max"]),
  max_tokens: z.number().int(), variables: z.array(Variable),
});
export type Prompt = z.infer<typeof Front> & { body: string };

export function load(name: string, version: number): Prompt {
  const file = path.join(ROOT, name, `v${version}.md`);
  if (!existsSync(file)) throw new Error(`no prompt ${name} v${version} at ${file}`);
  const [, front, body] = readFileSync(file, "utf8").split("---", 3);
  return { ...Front.parse(parse(front)), body: body.trim() };
}

export function render(p: Prompt, values: Record<string, string>): string {
  const spec = new Map(p.variables.map((v) => [v.name, v]));
  for (const k of Object.keys(values)) if (!spec.has(k)) throw new Error(`${p.name}: unknown ${k}`);
  for (const v of p.variables) {
    const val = values[v.name];
    if (v.required && val === undefined) throw new Error(`${p.name}: missing ${v.name}`);
    if (val !== undefined && v.max_chars && val.length > v.max_chars) throw new Error(`${p.name}: ${v.name} over ${v.max_chars}`);
    if (val !== undefined && v.enum && !v.enum.includes(val)) throw new Error(`${p.name}: ${v.name} not in enum`);
  }
  const out = p.body.replace(PLACEHOLDER, (_, k) => (values[k] ?? "").replaceAll(`</${k}>`, `<\\/${k}>`));
  if (PLACEHOLDER.test(out)) throw new Error(`${p.name}: unfilled placeholder`);
  return out;
}
```

Call site:

```typescript
import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { load, render } from "./prompts/index.js";

const client = new Anthropic();
const p = load("invoice_extract", 3);
const response = await client.messages.parse({
  model: p.model,
  max_tokens: p.max_tokens,
  output_config: { effort: p.effort, format: zodOutputFormat(InvoiceFields) },
  system: [{ type: "text", text: render(p, { locale: "en-IN" }), cache_control: { type: "ephemeral" } }],
  messages: [{ role: "user", content: `<input_text>\n${text}\n</input_text>` }],
});
```

Test (`src/prompts/prompts.test.ts`): same four assertions as Python;
print the count; fail on zero prompts.

## Changelog (`prompts/<name>/CHANGELOG.md`)

```
## v3 (2026-09-22, <owner>)  active  eval: 0.94 on evals/invoice_extract/cases.jsonl (v2: 0.91)
Changed: examples section; added the missing-GST edge case (targets cases 17, 23, 41).
Model: claude-sonnet-5 (unchanged).
```
