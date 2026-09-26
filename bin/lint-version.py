#!/usr/bin/env python3
"""lint-version: VERSION matches every plugin's plugin.json, the marketplace
metadata and every marketplace entry. The three Bearing plugins (bearing,
bearing-backend, bearing-apps) are released together, so one number holds for
all of them. Fails on an empty VERSION, on zero plugins and on any difference;
prints the number of fields it compared.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
v = (ROOT / "VERSION").read_text().strip() if (ROOT / "VERSION").exists() else ""
if not v:
    sys.exit("lint-version: VERSION is empty or missing")
market = json.loads((ROOT / ".claude-plugin" / "marketplace.json").read_text())
fields = [(".claude-plugin/marketplace.json metadata.version", market.get("metadata", {}).get("version"))]
entries = market.get("plugins", [])
for e in entries:
    fields.append((f".claude-plugin/marketplace.json plugins[{e.get('name')}].version", e.get("version")))
manifests = sorted((ROOT / "plugins").glob("*/.claude-plugin/plugin.json"))
for m in manifests:
    fields.append((str(m.relative_to(ROOT)), json.loads(m.read_text()).get("version")))
problems = [f"lint-version: {where} is {got}, VERSION is {v}" for where, got in fields if got != v]
names = {m.parent.parent.name for m in manifests}
listed = {e.get("name") for e in entries}
if not manifests:
    problems.append("lint-version: 0 plugin.json files under plugins/, nothing checked")
for missing in sorted(names - listed):
    problems.append(f"lint-version: plugins/{missing} is not listed in the marketplace")
for extra in sorted(listed - names):
    problems.append(f"lint-version: the marketplace lists {extra}, which has no plugins/{extra}/.claude-plugin/plugin.json")
for e in entries:
    want = f"./plugins/{e.get('name')}"
    if e.get("source") != want:
        problems.append(f"lint-version: marketplace entry {e.get('name')} has source {e.get('source')}, expected {want}")
if problems:
    print("\n".join(problems), file=sys.stderr)
    sys.exit(1)
print(f"lint-version: {len(fields)} fields match VERSION {v} ({len(manifests)} plugins, {len(entries)} marketplace entries)")
