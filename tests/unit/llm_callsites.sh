#!/usr/bin/env bash
# tests/unit/llm_callsites.sh: skills/llm-gateway/scripts/llm_callsites_check.py
# counts provider call sites from the code and passes only when every one
# is inside the gateway module. It fails, with file:line, on an Anthropic
# call, an SDK import or another provider outside llm/, and on empty input
# (no code file, zero call sites). node_modules and recordings are skipped.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/skills/llm-gateway/scripts/llm_callsites_check.py"

# fixture <dir>: a Python gateway with its provider, a TS gateway, two callers.
fixture() {
  mkdir -p "$1/app/llm" "$1/app/api" "$1/web/src/llm" "$1/web/src/routes" "$1/node_modules/x" "$1/tests/llm/recordings/summary"
  cat > "$1/app/llm/providers.py" <<'PY'
import anthropic

class AnthropicProvider:
    def __init__(self):
        self.client = anthropic.Anthropic(max_retries=2)

    def complete(self, **kw):
        return self.client.messages.create(**kw)
PY
  cat > "$1/app/api/summary.py" <<'PY'
from app.llm.gateway import Gateway, LLMRequest

def summarise(gw: Gateway, text: str) -> str:
    return gw.complete(LLMRequest(feature="summary", messages=[{"role": "user", "content": text}])).text
PY
  cat > "$1/web/src/llm/gateway.ts" <<'TS'
import Anthropic from "@anthropic-ai/sdk";
const client = new Anthropic();
export async function complete(req: unknown) { return client.messages.create(req as never); }
TS
  cat > "$1/web/src/routes/ask.ts" <<'TS'
import { complete } from "../llm/gateway.js";
export const ask = (q: string) => complete({ feature: "ask", q });
TS
  printf 'import Anthropic from "@anthropic-ai/sdk";\nnew Anthropic().messages.create({});\n' > "$1/node_modules/x/index.js"
  printf 'from anthropic import Anthropic\n' > "$1/tests/llm/recordings/summary/replay.py"
}
run() { python3 "$CHK" "$@"; }

t_begin "every call site inside llm/ passes with its counts"
d="$(tmpdir)/ok"; fixture "$d"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "llm-callsites: 4 files scanned, 6 call sites, 6 inside llm/, 0 outside, 2 files call the gateway"
assert_not_contains "$T_OUT" "node_modules"
t_end

t_begin "a direct Anthropic call outside llm/ fails with file:line"
d="$(tmpdir)/direct"; fixture "$d"
cat > "$d/app/api/legacy.py" <<'PY'
import os
from anthropic import Anthropic
client = Anthropic()
reply = client.messages.create(model="claude-opus-5", max_tokens=100, messages=[])
PY
assert_exit 1 run "$d"
assert_contains "$T_OUT" "outside: app/api/legacy.py:2: from anthropic import Anthropic"
assert_contains "$T_OUT" "outside: app/api/legacy.py:4: reply = client.messages.create("
assert_contains "$T_OUT" "9 call sites, 6 inside llm/, 3 outside"
t_end

t_begin "another provider or the raw endpoint outside llm/ fails"
d="$(tmpdir)/other"; fixture "$d"
printf 'import OpenAI from "openai";\nconst r = await new OpenAI().chat.completions.create({});\n' > "$d/web/src/routes/old.ts"
printf 'URL = "https://api.anthropic.com/v1/messages"\n' > "$d/app/api/raw.py"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "outside: web/src/routes/old.ts:1:"
assert_contains "$T_OUT" "outside: web/src/routes/old.ts:2:"
assert_contains "$T_OUT" "outside: app/api/raw.py:1:"
t_end

t_begin "--module names a different gateway directory"
d="$(tmpdir)/mod"; fixture "$d"
mv "$d/app/llm" "$d/app/ai"; mv "$d/web/src/llm" "$d/web/src/ai"
sed -i.bak 's/app\.llm\.gateway/app.ai.gateway/' "$d/app/api/summary.py"
sed -i.bak 's#\.\./llm/gateway#../ai/gateway#' "$d/web/src/routes/ask.ts"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 inside llm/"
assert_exit 0 run --module ai "$d"
assert_contains "$T_OUT" "6 inside ai/, 0 outside, 2 files call the gateway"
t_end

t_begin "no code file, zero call sites and a missing root fail"
d="$(tmpdir)/empty"; mkdir -p "$d/docs"
printf '# notes\n' > "$d/docs/README.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 files scanned, 0 call sites"
assert_contains "$T_OUT" "nothing checked"
printf 'def add(a, b):\n    return a + b\n' > "$d/app.py"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "1 files scanned, 0 call sites"
assert_exit 1 run "$d/nope"
assert_contains "$T_OUT" "is not a directory, nothing checked"
t_end

t_summary
