#!/usr/bin/env python3
"""gen-flow-steps: docs/flows.json -> plugins/bearing/bin/flow-steps.tsv.

One line per skill step, depth first through branch options in file order,
so brg-session can tell the next step without shipping the whole handbook.
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "plugins/bearing/bin/flow-steps.tsv"


def bare(skill):
    return skill.split(":")[-1].lstrip("/")


def walk(steps, acc):
    for s in steps:
        if s.get("kind") == "step" and s.get("skill"):
            name = bare(s["skill"])
            if name not in acc:
                acc.append(name)
        for opt in s.get("options", []):
            walk(opt.get("steps", []), acc)


def main():
    flows = json.loads((ROOT / "docs/flows.json").read_text())["flows"]
    lines = []
    for f in flows:
        acc = []
        walk(f.get("steps", []), acc)
        lines += [f"{f['id']}\t{i}\t{s}" for i, s in enumerate(acc, 1)]
    if not lines:
        raise SystemExit("gen-flow-steps: 0 steps found in docs/flows.json")
    OUT.write_text("\n".join(lines) + "\n")
    print(f"gen-flow-steps: {len(flows)} flows, {len(lines)} steps")


if __name__ == "__main__":
    main()
