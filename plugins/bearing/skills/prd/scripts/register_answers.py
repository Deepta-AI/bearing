#!/usr/bin/env python3
"""register_answers.py: resolve docs/product/questions.md in the session.

  register_answers.py rank  [--questions Q] [--status open] [--json]
  register_answers.py apply --answers A.json [--questions Q] [--date D] [--source S]

rank prints the register's open entries in the order the prd skill asks
them: open assumptions first, then the rest, each group by impact (the
number of REQ or story ids in Affects, ranges counted in full), then by
id. Each entry carries its readings split into options (a), (b)... with the
assumed one marked, so a session can put four of them in one
multiple-choice round. A register of 35 open points asked one at a time is
a wall; asked by impact, the first round settles the decisions that block
the most statements and the user can stop at any round.

apply writes the answers back. The answers file is a JSON object:
  {"Q-005": {"choice": "c"}, "Q-021": {"choice": "keep", "note": "..."},
   "Q-030": {"choice": "other", "note": "free text"},
   "Q-006": {"choice": "ask-client", "note": "AVM sales head"}}
A reading key or "keep" (the assumed decision) confirms the entry: Status
becomes confirmed, Decision states the answer with its date and source and
keeps the old decision as history. "other" records the free answer and
leaves the entry open for the session to judge (a new rule may need a new
REQ under step 7a, which a script must not write). Once judged, the
session applies {"choice": "decide", "decision": "..."}, which confirms
the entry with that decision and keeps the old one. "ask-client" leaves it
open with a dated note saying who was asked. The "Needs your
confirmation" list and the Entries/Open/Needs counts are rewritten, and
open assumptions are moved ahead of every other row, which the backlog
coverage gate requires.

Exit 1 when the register has no entries or the answers file holds no
answers: a run that checked nothing did not pass.
"""

import argparse
import datetime
import json
import re
import sys

HEADER = "| Q | Status | Kind | Where | Basis | Question | Readings | Decision | Why | Affects |"
NCOLS = 10
ROW = re.compile(r"^\| (Q-\d{3}) \|")
ID_RANGE = re.compile(r"\b([A-Z]+(?:-\d+)*-)(\d+) to \1(\d+)\b")
ID = re.compile(r"\b(?:REQ-\d{3}|US-\d+-\d+|[A-Z]{2,}-[A-Z0-9]+-\d+)\b")


def fail(msg):
    sys.exit(f"register_answers: {msg}")


def clean(text):
    return " ".join(str(text).replace("|", "/").split())


def load(path):
    try:
        lines = open(path, encoding="utf-8").read().split("\n")
    except OSError as e:
        fail(f"cannot read {path}: {e.strerror}")
    rows, idx = {}, []
    for n, line in enumerate(lines):
        m = ROW.match(line)
        if not m:
            continue
        cells = [c.strip() for c in line.strip().strip("|").split(" | ")]
        if len(cells) != NCOLS:
            fail(
                f"{m.group(1)} has {len(cells)} cells, wanted {NCOLS} (a '|' inside a cell?)"
            )
        rows[m.group(1)] = cells
        idx.append(n)
    if not rows:
        fail(f"0 register rows in {path}; nothing to rank or apply")
    return lines, rows, idx


def affects_count(cell):
    ids = set(ID.findall(cell))
    for m in ID_RANGE.finditer(cell):
        pre, lo, hi = m.group(1), int(m.group(2)), int(m.group(3))
        width = len(m.group(2))
        ids.update(f"{pre}{i:0{width}d}" for i in range(lo, hi + 1))
    return len(ids)


def options(readings):
    text = readings.split("Experiment:")[0]
    experiment = (
        readings.split("Experiment:", 1)[1].strip() if "Experiment:" in readings else ""
    )
    parts = re.split(r"(?:^|;\s*)\(([a-z])\)\s+", text.strip())
    opts = [
        {"key": parts[i], "text": parts[i + 1].strip().rstrip(";. ")}
        for i in range(1, len(parts) - 1, 2)
    ]
    return opts, experiment


def entry(cells):
    q, status, kind, where, basis, question, readings, decision, why, affects = cells
    opts, experiment = options(readings)
    m = re.match(r"\(([a-z])\)", decision)
    assumed = m.group(1) if m and any(o["key"] == m.group(1) for o in opts) else None
    return {
        "id": q,
        "status": status,
        "kind": kind,
        "basis": basis,
        "where": where,
        "question": question,
        "options": opts,
        "assumed": assumed,
        "decision": decision,
        "why": why,
        "experiment": experiment,
        "affects": affects_count(affects),
    }


def ranked(rows, status):
    es = [entry(c) for c in rows.values() if status == "all" or c[1] == status]
    return sorted(
        es, key=lambda e: (e["basis"] != "assumption", -e["affects"], e["id"])
    )


def cmd_rank(a):
    _, rows, _ = load(a.questions)
    es = ranked(rows, a.status)
    if a.json:
        print(json.dumps(es, indent=1, ensure_ascii=False))
    else:
        for n, e in enumerate(es, 1):
            print(
                f"{n:>3}. {e['id']} [{e['basis']}, affects {e['affects']}] {e['question']}"
            )
            for o in e["options"]:
                mark = "  (assumed)" if o["key"] == e["assumed"] else ""
                print(f"       ({o['key']}) {o['text']}{mark}")
            if e["assumed"] is None:
                print(f"       assumed: {e['decision']}")
    n_ass = sum(1 for e in es if e["basis"] == "assumption")
    print(
        f"rank: {len(es)} {a.status} entries ranked, {n_ass} assumptions first",
        file=sys.stderr,
    )


def cmd_apply(a):
    lines, rows, idx = load(a.questions)
    try:
        answers = json.load(open(a.answers, encoding="utf-8"))
    except (OSError, ValueError) as e:
        fail(f"cannot read answers {a.answers}: {e}")
    if not isinstance(answers, dict) or not answers:
        fail(f"0 answers in {a.answers}; nothing applied")
    date = a.date or datetime.date.today().isoformat()
    confirmed, review, asked, unknown = [], [], [], []
    for q, ans in answers.items():
        if q not in rows:
            unknown.append(q)
            continue
        cells, e = rows[q], entry(rows[q])
        choice = str(ans.get("choice", "")).strip().lower()
        note = clean(ans.get("note", ""))
        src = clean(ans.get("source") or a.source)
        old = cells[7]
        keys = {o["key"]: o["text"] for o in e["options"]}
        if choice == "keep" or (choice in keys and choice == e["assumed"]):
            new = f"confirmed {date} by {src} as assumed: {old}"
            cells[1] = "confirmed"
            confirmed.append(q)
        elif choice in keys:
            new = f"confirmed {date} by {src}: ({choice}) {clean(keys[choice])}; was: {old}"
            cells[1] = "confirmed"
            confirmed.append(q)
        elif choice == "other":
            if not note:
                fail(f"{q}: choice 'other' needs a note holding the answer")
            new = f"{old}; answered {date} by {src}, needs review: {note}"
            review.append(q)
            note = ""
        elif choice == "decide":
            decision = clean(ans.get("decision", ""))
            if not decision:
                fail(f"{q}: choice 'decide' needs the decision the session reached")
            new = f"confirmed {date} by {src}: {decision}; was: {old}"
            cells[1] = "confirmed"
            confirmed.append(q)
        elif choice == "ask-client":
            new = f"{old}; asked {note or 'the client'} on {date}"
            asked.append(q)
            note = ""
        else:
            fail(
                f"{q}: choice '{choice}' is not one of {sorted(keys)} or keep, other, decide, ask-client"
            )
        if note:
            new += f"; note: {note}"
        cells[7] = new
    if unknown:
        fail(f"answers for ids not in the register: {', '.join(unknown)}")

    # Open assumptions first (their order kept), then every other row by id.
    order = [q for q, c in rows.items() if c[1] == "open" and c[4] == "assumption"]
    order += sorted((q for q in rows if q not in order), key=lambda q: int(q[2:]))
    for n, q in zip(idx, order):
        lines[n] = "| " + " | ".join(rows[q]) + " |"

    text = "\n".join(lines)
    still = set(
        order[
            : sum(1 for c in rows.values() if c[1] == "open" and c[4] == "assumption")
        ]
    )
    out, in_needs = [], False
    for line in text.split("\n"):
        if line.startswith("## "):
            in_needs = line.startswith("## Needs your confirmation")
        m = re.match(r"^- (Q-\d{3})\b", line)
        if in_needs and m and m.group(1) not in still:
            continue
        out.append(line)
    text = "\n".join(out)
    n_open = sum(1 for c in rows.values() if c[1] == "open")
    text = re.sub(
        r"^Entries: \d+\s+Open: \d+\s+Needs your confirmation: \d+",
        f"Entries: {len(rows)}   Open: {n_open}   Needs your confirmation: {len(still)}",
        text,
        count=1,
        flags=re.M,
    )
    open(a.questions, "w", encoding="utf-8").write(text)
    print(
        f"apply: {len(answers)} answers read; confirmed {len(confirmed)}"
        f"{' (' + ', '.join(confirmed) + ')' if confirmed else ''}; needs review {len(review)}"
        f"{' (' + ', '.join(review) + ')' if review else ''}; asked the client {len(asked)}; "
        f"register now {n_open} open of {len(rows)}, {len(still)} need confirmation"
    )


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("rank")
    r.add_argument("--questions", default="docs/product/questions.md")
    r.add_argument("--status", default="open", choices=["open", "confirmed", "all"])
    r.add_argument("--json", action="store_true")
    ap = sub.add_parser("apply")
    ap.add_argument("--questions", default="docs/product/questions.md")
    ap.add_argument("--answers", required=True)
    ap.add_argument("--date")
    ap.add_argument("--source", default="the user in session")
    a = p.parse_args()
    cmd_rank(a) if a.cmd == "rank" else cmd_apply(a)


if __name__ == "__main__":
    main()
