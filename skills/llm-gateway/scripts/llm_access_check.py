#!/usr/bin/env python3
"""llm_access_check: prove the product can reach every model provider its
routing.yaml names, before a demo, a deploy or a hackathon starts.

A Claude Code subscription pays for building the product. The product's own
model calls are separate: they need an API key, an OpenRouter key or a
served endpoint of their own. This check reads llm/routing.yaml (or the path
given), collects the provider of every model under `models:`, and checks
that each provider's credentials are present in the environment:

  anthropic   ANTHROPIC_API_KEY
  openrouter  OPENROUTER_API_KEY
  openai      OPENAI_API_KEY
  vllm        the model's base_url, and the variable it names (${VAR}) set
  openai_compatible  as vllm

A `.env` file beside the repository root is read for names only when the
variable is not already in the environment (values are never printed).

With --live it also makes one free request per provider (a models or key
listing, never a completion): anthropic GET /v1/models, openrouter GET
/api/v1/key (which also reports the key's remaining credit), openai GET
/v1/models, vllm GET <base_url>/models. --live needs a Python with ssl.

Usage: llm_access_check.py [--routing llm/routing.yaml] [--env .env] [--live]
Prints one line per provider, then
  llm-access: M models, P providers checked, R ready, X missing[, L live ok]
and exits 1 when zero models were read, when any provider is missing its
credentials or names an unknown provider, or when a live request fails.
"""

import argparse
import json
import os
import re
import sys

KEYS = {
    "anthropic": "ANTHROPIC_API_KEY",
    "openrouter": "OPENROUTER_API_KEY",
    "openai": "OPENAI_API_KEY",
}
URL_PROVIDERS = {"vllm", "openai_compatible"}
LIVE = {
    "anthropic": ("https://api.anthropic.com/v1/models", "x-api-key"),
    "openrouter": ("https://openrouter.ai/api/v1/key", "authorization"),
    "openai": ("https://api.openai.com/v1/models", "authorization"),
}


def read_models(path):
    """Return {model: {provider, base_url}} from the `models:` block, stdlib only."""
    models, current, inside = {}, None, False
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.split("#", 1)[0].rstrip()
            if not line.strip():
                continue
            indent = len(line) - len(line.lstrip())
            if indent == 0:
                inside = line.strip() == "models:"
                current = None
                continue
            if not inside:
                continue
            key, _, value = line.strip().partition(":")
            value = value.strip().strip("\"'")
            if indent == 2 and not value:
                current = key
                models[current] = {}
            elif current and indent > 2 and key in ("provider", "base_url"):
                models[current][key] = value
    return models


def read_env_names(path):
    found = {}
    if path and os.path.isfile(path):
        with open(path, encoding="utf-8") as fh:
            for raw in fh:
                m = re.match(r"\s*(?:export\s+)?([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$", raw)
                if m and m.group(2).strip().strip("\"'"):
                    found[m.group(1)] = m.group(2).strip().strip("\"'")
    return found


def lookup(name, dotenv):
    return os.environ.get(name) or dotenv.get(name)


def live_request(url, header, secret):
    try:
        import ssl  # noqa: F401  (urllib needs it for https)
        import urllib.request
    except ImportError:
        return False, "this Python has no ssl; run --live with one that does"
    value = secret if header == "x-api-key" else f"Bearer {secret}"
    headers = {header: value}
    if header == "x-api-key":
        headers["anthropic-version"] = "2023-06-01"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read(65536).decode("utf-8", "replace")
    except Exception as exc:  # network, 401, 403: all mean not ready
        return False, type(exc).__name__ + ": " + str(exc)[:120]
    note = ""
    if "openrouter" in url:
        try:
            data = json.loads(body).get("data", {})
            limit, usage = data.get("limit"), data.get("usage")
            if limit is not None and usage is not None:
                note = f" (credit left {float(limit) - float(usage):.2f} of {float(limit):.2f})"
            elif usage is not None:
                note = f" (no limit set, used {float(usage):.2f})"
        except (ValueError, TypeError, AttributeError):
            pass
    return True, "ok" + note


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--routing", default="llm/routing.yaml")
    ap.add_argument("--env", default=".env")
    ap.add_argument("--live", action="store_true")
    args = ap.parse_args()

    if not os.path.isfile(args.routing):
        print(f"llm-access: {args.routing} not found; 0 models, 0 providers checked")
        return 1
    models = read_models(args.routing)
    dotenv = read_env_names(args.env)

    providers = {}
    for name, spec in models.items():
        providers.setdefault(spec.get("provider", "?"), []).append((name, spec))

    ready = missing = live_ok = 0
    for provider in sorted(providers):
        names = ", ".join(n for n, _ in providers[provider])
        if provider in KEYS:
            var = KEYS[provider]
            secret = lookup(var, dotenv)
            ok, detail = bool(secret), f"{var} {'set' if secret else 'NOT SET'}"
            if ok and args.live:
                url, header = LIVE[provider]
                ok, result = live_request(url, header, secret)
                detail += f", live {result}"
                live_ok += ok
        elif provider in URL_PROVIDERS:
            urls = [s.get("base_url", "") for _, s in providers[provider]]
            unset = []
            for url in urls:
                for var in re.findall(r"\$\{([A-Z_][A-Z0-9_]*)\}", url):
                    if not lookup(var, dotenv):
                        unset.append(var)
            ok = all(urls) and not unset
            detail = "base_url " + ("missing" if not all(urls) else "set")
            if unset:
                detail += ", NOT SET: " + ", ".join(sorted(set(unset)))
            if ok and args.live:
                base = urls[0]
                for var in re.findall(r"\$\{([A-Z_][A-Z0-9_]*)\}", base):
                    base = base.replace("${" + var + "}", lookup(var, dotenv))
                ok, result = live_request(
                    base.rstrip("/") + "/models", "authorization", "none"
                )
                detail += f", live {result}"
                live_ok += ok
        else:
            ok, detail = (
                False,
                "unknown provider (expected one of "
                + ", ".join(sorted(set(KEYS) | URL_PROVIDERS))
                + ")",
            )
        print(f"{'ready' if ok else 'MISSING'}: {provider} [{names}]: {detail}")
        ready += ok
        missing += not ok

    tail = f", {live_ok} live ok" if args.live else ""
    print(
        f"llm-access: {len(models)} models, {len(providers)} providers checked, {ready} ready, {missing} missing{tail}"
    )
    return 0 if models and not missing else 1


if __name__ == "__main__":
    sys.exit(main())
