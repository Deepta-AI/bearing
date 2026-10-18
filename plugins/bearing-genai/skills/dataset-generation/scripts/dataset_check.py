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
user turns (a string, or a list of content blocks whose `text` is
read); the system prompt is shared by every row and is not compared.
`source` is any non-empty string: `owner` is counted by name; `synthetic`,
`teacher`, and any `<generator>:` prefix (`synthetic:x`, `teacher:<model>`,
`<model>:<tag>` such as `claude-opus-5-5:v2`, `llama3:8b` or `gpt4o`) count
as synthetic; every other value is real.

Comparison text: a string as is; an object as canonical JSON with sorted
keys; then NFKC-normalised, format characters (Unicode category Cf, such
as zero-width spaces) removed, lower-cased, whitespace collapsed.
Contamination targets of a case: its input as canonical JSON, its string values joined, and each
string value of 20 or more characters on its own, so a chat row, a string
row, or a row that repeats one field (a question without its context) is
caught. A row is contaminated by an exact match of any target, a near
match (character 5-gram Jaccard at or above --near), or containment: the
share of a target's 5-grams found in the row at or above the same
--near, which catches a row that wraps a case ("Classify: <case text>").
Containment can also flag a long row that quotes a short case; targets
under 20 characters are not checked for it. One threshold, --near
(default 0.8), serves duplicates, contamination and containment. Above
20,000 rows only exact matches are checked.

Taxonomy: {"dimensions": {dim: [values]}}; cells are the product of the
values. Audit rows: {"id", "verdict": "accept"|"reject", "by"}; a row
without `by` is not a person's audit and does not count. Required audit is
min(synthetic, max(30, ceil(f x synthetic))) with f 0.2 for kind eval
(llm-eval's rule that a person checks 20% of model-labelled cases) and
0.1 for train and preference; acceptance must be at
least 90%. For kind eval the synthetic share of the rows plus --against
cases is at most 0.5.

Output: one count line, then `dataset-check: passed` (exit 0) or
`dataset-check: X problems` and one line per problem (exit 1). Zero rows,
or a rows, --against, --audit or --taxonomy file that cannot be read,
prints `dataset-check: 0 rows checked, nothing checked (...)` and exits 2.
"""

import argparse
import json
import math
import re
import sys
import unicodedata

NEAR_CAP = 20000
GRAM = 5
LONG = 20  # a case string value this long is a contamination target alone
SYN_HEADS = {"synthetic", "teacher", "generated", "distilled"}
# A model family, then nothing, a version digit (llama3, gpt4o, qwen2.5) or a
# separator (claude-opus-5-5). The o-series already ends in its digit, so it
# takes a separator only and a real source such as `o365` stays real.
MODEL_HEAD = re.compile(
    r"^(?:(claude|gpt|gemini|gemma|llama|qwen|mistral|mixtral|deepseek|phi|command|grok)"
    r"(\d[\w.-]*|[-_.][\w.-]*)?|o[134]([-_.][\w.-]*)?)$"
)


def die(msg):
    print(f"dataset-check: 0 rows checked, nothing checked ({msg})")
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
    """NFKC, drop format characters (zero-width space and joiner, BOM, soft
    hyphen: category Cf), lower-case, collapse whitespace."""
    s = unicodedata.normalize("NFKC", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Cf")
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


def content_text(c):
    """Text of a chat message content: a string, or content blocks."""
    if isinstance(c, str):
        return [c]
    if isinstance(c, list):
        out = []
        for b in c:
            out.extend(content_text(b))
        return out
    if isinstance(c, dict):
        if isinstance(c.get("text"), str):
            return [c["text"]]
        if "content" in c:
            return content_text(c["content"])
        return leaves({k: v for k, v in c.items() if k not in ("type", "source")})
    return leaves(c)


def user_turns(msgs):
    if not isinstance(msgs, list):
        return None
    parts = []
    for m in msgs:
        if isinstance(m, dict) and m.get("role") == "user":
            parts.extend(content_text(m.get("content")))
    return " ".join(parts) if parts else None


def raw_input(row):
    inp = row.get("input")
    if inp is None:
        inp = user_turns(row.get("messages"))
    if inp is None:
        inp = (
            user_turns(row.get("prompt"))
            if isinstance(row.get("prompt"), list)
            else row.get("prompt")
        )
    return inp


def texts(row):
    """(canonical, plain) comparison texts of a row's input, or None."""
    inp = raw_input(row)
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


class ContainIndex:
    """Targets T contained in a row R: |T & R| / |T| >= t. Any
    len - ceil(t * len) + 1 grams of T include one that is in R, so T is
    indexed by that many of its rarest grams."""

    def __init__(self, t, order):
        self.t, self.order, self.post, self.sets = t, order, {}, []

    def add(self, g):
        i = len(self.sets)
        self.sets.append(g)
        ranked = sorted(g, key=lambda x: (self.order.get(x, 0), x))
        keep = len(ranked) - math.ceil(self.t * len(ranked) - 1e-9) + 1
        for x in ranked[: max(keep, 1)]:
            self.post.setdefault(x, []).append(i)

    def hit(self, g):
        seen = set()
        for x in g:
            for i in self.post.get(x, ()):
                if i in seen:
                    continue
                seen.add(i)
                if len(self.sets[i] & g) >= self.t * len(self.sets[i]) - 1e-9:
                    return True
        return False


def case_targets(case):
    """(exact strings, near and containment texts) of one golden case."""
    t = texts(case)
    if t is None:
        return set(), []
    canon, plain = t
    inp = raw_input(case)
    longs = []
    if not isinstance(inp, str):
        for v in leaves(inp):
            n = norm(v)
            if len(n) >= LONG and n != plain and n not in longs:
                longs.append(n)
    return {canon, plain, *longs}, [plain] + longs


def frequency(*gram_lists):
    freq = {}
    for gl in gram_lists:
        for g in gl:
            for x in g:
                freq[x] = freq.get(x, 0) + 1
    return freq


def source_kind(src):
    s = src.strip().lower()
    if s == "owner":
        return "owner"
    head = s.split(":", 1)[0].strip()
    if head in SYN_HEADS or MODEL_HEAD.match(head):
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

    for what, path in (
        ("rows", a.rows),
        ("--against", a.against),
        ("--audit", a.audit),
        ("--taxonomy", a.taxonomy),
    ):
        if path is None:
            continue
        try:
            open(path, encoding="utf-8").close()
        except OSError as e:
            die(f"cannot read {what} {path}: {e.strerror}")

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
            ex, near_t = case_targets(c)
            if near_t:
                against.append((c.get("id"), ex, near_t, c.get("source")))

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
    case_grams = (
        [grams(p) for _, _, ts, _ in against for p in ts] if near_on else []
    )
    if near_on:
        order = frequency(row_grams, case_grams)
        idx = NearIndex(a.near, order)
        for (rid, _, _), g in zip(uniq, row_grams):
            if idx.hit(g):
                near += 1
            idx.add(g)

    # contamination
    case_exact = set()
    for _, ex, _, _ in against:
        case_exact |= ex
    cidx = kidx = None
    if near_on and against:
        cidx = NearIndex(a.near, order)
        kidx = ContainIndex(a.near, order)
        texts_flat = [p for _, _, ts, _ in against for p in ts]
        for p, g in zip(texts_flat, case_grams):
            cidx.add(g)
            if len(p) >= LONG:
                kidx.add(g)
    contaminated = 0
    for i, (rid, canon, plain) in enumerate(keyed):
        hit = canon in case_exact or plain in case_exact
        if not hit and cidx is not None:
            g = grams(plain)
            hit = cidx.hit(g) or kidx.hit(g)
        if hit:
            contaminated += 1
            problems.append(f"{rid}: contaminated, matches a case in {a.against}")

    # audit
    share = 0.2 if a.kind == "eval" else 0.1
    required = min(len(syn_ids), max(30, math.ceil(share * len(syn_ids))))
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
