#!/usr/bin/env python3
"""llm_callsites_check: count every model provider call site in the
repository and prove each one sits inside the gateway module, so the
"call sites" lines in llm-gateway's report are computed, not claimed.

A call site is a line in a .py, .ts, .tsx, .js, .jsx, .mjs or .cjs file
that constructs a provider client, calls it, imports its SDK or names its
endpoint:
  - Anthropic: `import anthropic`, `from anthropic`, `@anthropic-ai/sdk`,
    `Anthropic(`, `AsyncAnthropic(`, `.messages.create(`,
    `.messages.stream(`, `.messages.parse(`, `tool_runner(`,
    `toolRunner(`, `api.anthropic.com`;
  - other providers: `openai` (import or `OpenAI(`), `chat.completions.create(`,
    `google.genai`, `@google/genai`, `generate_content(`, `generateContent(`,
    `mistralai`, `cohere`, `ollama`.
One line counts once, however many patterns it matches.

Inside the gateway module means a path with a directory named by --module
(default `llm`, so `llm/`, `app/llm/`, `src/llm/` and `tests/llm/` all
count). Skipped: node_modules, .venv, venv, .git, dist, build, and the
recordings directory.

Usage: llm_callsites_check.py [--module NAME] [root]
Prints one "outside:" line per call site outside the module, then
  llm-callsites: F files scanned, N call sites, G inside <module>/, O outside, C files call the gateway
and exits 1 on any call site outside the module, or when zero files or
zero call sites were read (a gateway has at least its own provider call).
"""

import argparse
import os
import re
import sys

EXT = {".py", ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"}
SKIP = {
    "node_modules",
    ".venv",
    "venv",
    ".git",
    "dist",
    "build",
    "recordings",
    "__pycache__",
}
CALL = re.compile(
    r"^\s*import\s+anthropic\b|^\s*from\s+anthropic\b|@anthropic-ai/sdk|\b(Async)?Anthropic\("
    r"|\.messages\.(create|stream|parse)\(|\btool_runner\(|\btoolRunner\(|api\.anthropic\.com"
    r"|^\s*(import|from)\s+openai\b|['\"]openai['\"]|\b(Async)?OpenAI\(|chat\.completions\.create\("
    r"|google\.genai|@google/genai|\bgenerate_content\(|\bgenerateContent\("
    r"|\bmistralai\b|['\"]cohere(-ai)?['\"]|^\s*(import|from)\s+cohere\b"
    r"|['\"]ollama['\"]|^\s*(import|from)\s+ollama\b"
)


def gateway_import(module):
    m = re.escape(module)
    return re.compile(
        r"^\s*from\s+([\w.]+\.)?" + m + r"(\.[\w.]+)?\s+import\b"
        r"|^\s*import\s+([\w.]+\.)?" + m + r"\b"
        r"|from\s+['\"][^'\"]*\b" + m + r"(/[^'\"]*)?['\"]"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--module", default="llm")
    ap.add_argument("root", nargs="?", default=".")
    a = ap.parse_args()
    if not os.path.isdir(a.root):
        print(
            f"llm-callsites: {a.root} is not a directory, nothing checked",
            file=sys.stderr,
        )
        return 1
    uses_gateway = gateway_import(a.module)
    files = inside = 0
    outside, callers = [], 0
    for root, dirs, names in os.walk(a.root):
        dirs[:] = sorted(d for d in dirs if d not in SKIP)
        for n in sorted(names):
            if os.path.splitext(n)[1] not in EXT:
                continue
            path = os.path.join(root, n)
            rel = os.path.relpath(path, a.root)
            in_module = a.module in rel.split(os.sep)[:-1]
            files += 1
            calls_gateway = False
            with open(path, encoding="utf-8", errors="replace") as f:
                for i, line in enumerate(f, 1):
                    if CALL.search(line):
                        if in_module:
                            inside += 1
                        else:
                            outside.append(f"{rel}:{i}: {line.strip()[:120]}")
                    elif not in_module and uses_gateway.search(line):
                        calls_gateway = True
            callers += calls_gateway
    for o in outside:
        print(f"outside: {o}")
    total = inside + len(outside)
    print(
        f"llm-callsites: {files} files scanned, {total} call sites, {inside} inside {a.module}/, "
        f"{len(outside)} outside, {callers} files call the gateway"
    )
    if files == 0 or total == 0:
        print(
            f"llm-callsites: {files} files, {total} call sites, nothing checked "
            f"(the gateway's own provider call is one)",
            file=sys.stderr,
        )
        return 1
    return 1 if outside else 0


if __name__ == "__main__":
    sys.exit(main())
