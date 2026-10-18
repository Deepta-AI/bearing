#!/usr/bin/env python3
"""dataset_check: the gate a generated dataset passes before anyone uses it.

Usage:
  dataset_check.py <rows.jsonl> --kind eval|train|preference
                   [--against <cases.jsonl>] [--taxonomy <taxonomy.json>]
                   [--audit <audit.jsonl>] [--near 0.8] [--max-near 0.02]

Rows (JSON Lines) come in the shapes llm-eval and llm-fine-tuning write:
  {"id", "input": str | object, "source": str, "cell": {dim: value}, ...}
plus `expected` or `rubric` (eval), `output` or chat `messages` with an
assistant turn (train), `chosen` and `rejected` (preference). A chat row
(`messages`, or `prompt` for a preference pair) takes its input from the
user turns; the system prompt is shared by every row and is not compared.
`source` is any non-empty string: `owner` and `synthetic` (or
`synthetic:<generator>`) are counted by name, every other value as real.

Comparison text: a string as is; an object as canonical JSON with sorted
keys; then lower-cased with whitespace collapsed. Contamination also
compares the object's string values alone, so a chat row or a string row
that repeats an object case is caught. Near duplicate: character 5-gram
Jaccard at or above --near (one threshold for duplicates and for
contamination). Above 20,000 rows only exact matches are checked.

Taxonomy: {"dimensions": {dim: [values]}}; cells are the product of the
values. Audit rows: {"id", "verdict": "accept"|"reject", "by"}; a row
without `by` is not a person's audit and does not count. Required audit is
min(synthetic, max(30, ceil(0.1 x synthetic))); acceptance must be at
least 90%. For kind eval the synthetic share of the rows plus --against
cases is at most 0.5.

Output: one count line, then `dataset-check: passed` (exit 0) or
`dataset-check: X problems` and one line per problem (exit 1). Zero rows,
or a file that cannot be read, prints `nothing checked` and exits 2.
"""

import argparse
import json
import math
import sys

NEAR_CAP = 20000
GRAM = 5


def die(msg):
    print(f"dataset-check: nothing checked ({msg})")
    sys.exit(2)


def read_jsonl(path, what, problems):
    rows = []
    try:
        fh = open(path, encoding="utf-8")
    except OSError as e:
        die(f"cannot read {what} {path}: {e.strerror}")
    with fh:
        for n, line in enumerate(fh, 1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                problems.append(f"{what} line {n}: not JSON")
                continue
            if not isinstance(row, dict):
                problems.append(f"{what} line {n}: not an object")
                continue
            rows.append(row)
    return rows


def norm(s):
    return " ".join(s.lower().split())


def leaves(v):
    if isinstance(v, dict):
        out = []
        for k in sorted(v):
            out.extend(leaves(v[k]))
        return out
    if isinstance(v, list):
        out = []
        for x in v:
            out.extend(leaves(x))
        return out
    if v is None:
        return []
    return [v if isinstance(v, str) else json.dumps(v)]


def user_turns(msgs):
    if not isinstance(msgs, list):
        return None
    parts = [
        m.get("content")
        for m in msgs
        if isinstance(m, dict) and m.get("role") == "user"
    ]
    parts = [p if isinstance(p, str) else json.dumps(p, sort_keys=True) for p in parts]
    return " ".join(parts) if parts else None


def texts(row):
    """(canonical, plain) comparison texts of a row's input, or None."""
    inp = row.get("input")
    if inp is None:
        inp = user_turns(row.get("messages"))
    if inp is None:
        inp = (
            user_turns(row.get("prompt"))
            if isinstance(row.get("prompt"), list)
            else row.get("prompt")
        )
    if inp is None or inp == "" or inp == {}:
        return None
    if isinstance(inp, str):
        t = norm(inp)
        return (t, t) if t else None
    canon = norm(json.dumps(inp, sort_keys=True, ensure_ascii=False))
    plain = norm(" ".join(leaves(inp)))
    return canon, plain


def grams(s):
    if len(s) < GRAM:
        return {s}
    return {s[i : i + GRAM] for i in range(len(s) - GRAM + 1)}


def jaccard(a, b):
    inter = len(a & b)
    return inter / (len(a) + len(b) - inter) if inter else 0.0


class NearIndex:
    """Prefix-filter index: two sets with Jaccard >= t share a gram among
    the first len - ceil(t * len) + 1 grams of each, in one global order."""

    def __init__(self, t, order):
        self.t, self.order, self.post, self.sets = t, order, {}, []

    def prefix(self, g):
        ranked = sorted(g, key=lambda x: (self.order.get(x, 0), x))
        keep = len(ranked) - math.ceil(self.t * len(ranked) - 1e-9) + 1
        return ranked[: max(keep, 1)]

    def add(self, g):
        i = len(self.sets)
        self.sets.append(g)
        for x in self.prefix(g):
            self.post.setdefault(x, []).append(i)

    def hit(self, g):
        seen = set()
        for x in self.prefix(g):
            for i in self.post.get(x, ()):
                if i in seen:
                    continue
                seen.add(i)
                if jaccard(g, self.sets[i]) >= self.t:
                    return True
        return False


def frequency(*gram_lists):
    freq = {}
    for gl in gram_lists:
        for g in gl:
            for x in g:
                freq[x] = freq.get(x, 0) + 1
    return freq


def source_kind(src):
    if src == "owner":
        return "owner"
    if src == "synthetic" or src.startswith("synthetic:"):
        return "synthetic"
    return "real"


def has_assistant(msgs):
    return isinstance(msgs, list) and any(
        isinstance(m, dict) and m.get("role") == "assistant" and m.get("content")
        for m in msgs
    )


def filled(v):
    return v is not None and v != "" and v != [] and v != {}


def main():
    ap = argparse.ArgumentParser(description="Gate a generated dataset.")
    ap.add_argument("rows")
    ap.add_argument("--kind", required=True, choices=["eval", "train", "preference"])
    ap.add_argument("--against")
    ap.add_argument("--taxonomy")
    ap.add_argument("--audit")
    ap.add_argument("--near", type=float, default=0.8)
    ap.add_argument("--max-near", type=float, default=0.02)
    a = ap.parse_args()
    if not 0 < a.near <= 1:
        die("--near must be in (0, 1]")

    problems = []
    rows = read_jsonl(a.rows, "rows", problems)
    if not rows:
        die(f"0 rows in {a.rows}")

    # per-row shape
    counts = {"real": 0, "owner": 0, "synthetic": 0}
    syn_ids = set()
    keyed = []  # (id, canonical, plain) for rows with an input
    for n, row in enumerate(rows, 1):
        rid = row.get("id")
        if not isinstance(rid, str) or not rid:
            rid = f"line {n}"
            problems.append(f"{rid}: missing id")
        src = row.get("source")
        if not isinstance(src, str) or not src.strip():
            problems.append(f"{rid}: missing source")
        else:
            k = source_kind(src.strip())
            counts[k] += 1
            if k == "synthetic":
                syn_ids.add(rid)
        t = texts(row)
        if t is None:
            problems.append(f"{rid}: missing input")
        else:
            keyed.append((rid, t[0], t[1]))
        if a.kind == "eval" and not (
            filled(row.get("expected")) or filled(row.get("rubric"))
        ):
            problems.append(f"{rid}: no expected or rubric")
        if a.kind == "train" and not (
            filled(row.get("output")) or has_assistant(row.get("messages"))
        ):
            problems.append(f"{rid}: no output or assistant turn")
        if a.kind == "preference":
            for f in ("chosen", "rejected"):
                if not filled(row.get(f)):
                    problems.append(f"{rid}: no {f}")
            if filled(row.get("chosen")) and row.get("chosen") == row.get("rejected"):
                problems.append(f"{rid}: chosen equals rejected")

    # taxonomy cells
    cells_part = None
    if a.taxonomy:
        try:
            tax = json.load(open(a.taxonomy, encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as e:
            die(f"cannot read taxonomy {a.taxonomy}: {e}")
        dims = tax.get("dimensions") if isinstance(tax, dict) else None
        if (
            not isinstance(dims, dict)
            or not dims
            or not all(isinstance(v, list) and v for v in dims.values())
        ):
            problems.append(
                f"taxonomy {a.taxonomy}: 0 dimensions or a dimension with no values"
            )
            dims = {}
        names = sorted(dims)
        total = 1
        for k in names:
            total *= len(dims[k])
        seen = {}
        for n, row in enumerate(rows, 1):
            rid = row.get("id") or f"line {n}"
            cell = row.get("cell")
            if not isinstance(cell, dict):
                problems.append(f"{rid}: no cell")
                continue
            key = tuple(cell.get(k) for k in names)
            if any(cell.get(k) not in dims[k] for k in names):
                problems.append(
                    f"{rid}: cell outside the taxonomy ({json.dumps(cell, sort_keys=True)})"
                )
                continue
            seen[key] = seen.get(key, 0) + 1
        for key in sorted(seen, key=str):
            label = ",".join(f"{k}={v}" for k, v in zip(names, key))
            print(f"  cell {label}: {seen[key]} rows")
        cells_part = f"cells {len(seen)} of {total} filled ({total - len(seen)} empty)"
    else:
        distinct = {
            json.dumps(r.get("cell"), sort_keys=True)
            for r in rows
            if isinstance(r.get("cell"), dict)
        }
        cells_part = f"cells {len(distinct)} seen (no taxonomy)"

    # duplicates
    near_on = len(rows) <= NEAR_CAP
    against = []
    if a.against:
        cases = read_jsonl(a.against, "against", problems)
        if not cases:
            problems.append(
                f"--against {a.against}: 0 cases, nothing to check contamination against"
            )
        for c in cases:
            t = texts(c)
            if t is not None:
                against.append((c.get("id"), t[0], t[1], c.get("source")))

    exact_seen = set()
    dup = 0
    near = 0
    uniq = []
    for rid, canon, plain in keyed:
        if canon in exact_seen or plain in exact_seen:
            dup += 1
            problems.append(f"{rid}: exact duplicate of an earlier row")
            continue
        exact_seen.add(canon)
        exact_seen.add(plain)
        uniq.append((rid, canon, plain))

    row_grams = [grams(p) for _, _, p in uniq] if near_on else []
    case_grams = [grams(p) for _, _, p, _ in against] if near_on else []
    if near_on:
        order = frequency(row_grams, case_grams)
        idx = NearIndex(a.near, order)
        for (rid, _, _), g in zip(uniq, row_grams):
            if idx.hit(g):
                near += 1
            idx.add(g)

    # contamination
    case_exact = set()
    for _, canon, plain, _ in against:
        case_exact.add(canon)
        case_exact.add(plain)
    cidx = None
    if near_on and against:
        cidx = NearIndex(a.near, order)
        for g in case_grams:
            cidx.add(g)
    contaminated = 0
    for i, (rid, canon, plain) in enumerate(keyed):
        hit = canon in case_exact or plain in case_exact
        if not hit and cidx is not None:
            hit = cidx.hit(grams(plain))
        if hit:
            contaminated += 1
            problems.append(f"{rid}: contaminated, matches a case in {a.against}")

    # audit
    required = min(len(syn_ids), max(30, math.ceil(0.1 * len(syn_ids))))
    verdicts = {}
    if a.audit:
        for n, r in enumerate(read_jsonl(a.audit, "audit", problems), 1):
            if r.get("id") not in syn_ids:
                continue
            if r.get("verdict") not in ("accept", "reject"):
                problems.append(f"audit line {n}: verdict is not accept or reject")
                continue
            if not isinstance(r.get("by"), str) or not r["by"].strip():
                problems.append(f"audit line {n}: no `by`, not a person's audit")
                continue
            verdicts[r["id"]] = r["verdict"]
    audited = len(verdicts)
    accepted = sum(1 for v in verdicts.values() if v == "accept")
    pct = f"{100.0 * accepted / audited:.1f}%" if audited else "n/a"
    if audited < required:
        problems.append(
            f"audit: {audited} of {required} synthetic rows audited by a person"
        )
    if audited and accepted * 10 < audited * 9:
        problems.append(
            f"audit: accepted {pct}, below 90%; the batch goes back to generation"
        )

    if a.kind == "eval":
        syn_total = len(syn_ids) + sum(
            1
            for _, _, _, s in against
            if isinstance(s, str) and source_kind(s) == "synthetic"
        )
        whole = len(rows) + len(against)
        if syn_total * 2 > whole:
            problems.append(
                f"synthetic share {syn_total} of {whole} ({100.0 * syn_total / whole:.1f}%) is over half of the eval set"
            )

    if near_on and keyed and near / len(rows) > a.max_near:
        problems.append(
            f"near duplicates {near} of {len(rows)} rows, over --max-near {a.max_near}"
        )

    near_part = (
        f"near duplicates {near}"
        if near_on
        else f"near duplicates: skipped above {NEAR_CAP} rows"
    )
    print(
        f"dataset-check: {len(rows)} rows (real {counts['real']}, owner {counts['owner']}, "
        f"synthetic {counts['synthetic']}), {cells_part}, exact duplicates {dup}, {near_part}, "
        f"contaminated {contaminated} against {len(against)} cases, "
        f"audited {audited} of {required} required (accepted {pct})"
    )
    if problems:
        print(f"dataset-check: {len(problems)} problems")
        for p in problems:
            print(f"  {p}")
        sys.exit(1)
    print("dataset-check: passed")


if __name__ == "__main__":
    main()
