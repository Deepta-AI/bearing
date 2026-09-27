#!/usr/bin/env python3
"""progress: the committed, per-task progress record in docs/progress/.

The session state in .bearing/state/ is local to one machine and ignored by
git. This file is the shared summary: one file per task, committed on the
task branch, so a second engineer or a fresh clone sees what is in flight.
Each branch only ever writes its own file, so two branches never conflict.

  write --task ID [--field value ...]
      Upsert fields in docs/progress/<ID>.md, creating it from
      skills/session-handoff/templates/progress.md (guidance comments removed).
      Only the named fields change; Updated is set to today (UTC) on every
      write; Started, Owner (the latest commit's author), Branch and Status
      get defaults on create.
      Scalars: --title --branch --status --owner --criteria --next --mr
      --ticket. Lists (repeat the flag; the given items replace the list,
      "none" clears it): --done --blocker --decision. Appending:
      --add-done --add-decision (an item already present is not repeated).
      A file that would reach 40 lines folds the oldest Done items into one
      "N earlier items" line.
  index [--root DIR] [--status S] [--open] [--refs]
      A table of every docs/progress/*.md (task, status, owner, updated,
      next) and a final "progress: N tasks (...)" line counting each status.
      --open leaves out merged and abandoned. --refs also reads the file
      from every local and remote-tracking branch (git ls-tree), so tasks
      still on unmerged branches show; the newest Updated wins per task.
      Exits 1 when there are zero progress files.
  check [--root DIR]
      Exits 1 when a file lacks a required field (Next may be "none" once
      merged or abandoned), has an unknown status or
      a malformed date, is 40 lines or more, or is named for another task;
      prints each problem and the counts. Zero files is a failure too.

python3 stdlib only. Exit codes: 0 ok, 1 findings or empty input, 2 usage.
"""

import argparse
import datetime
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, "..", "templates", "progress.md")
STATUSES = ["started", "in progress", "blocked", "in review", "merged", "abandoned"]
CLOSED = {"merged", "abandoned"}
# field name -> label in the file
SCALARS = [
    ("task", "Task"),
    ("title", "Title"),
    ("branch", "Branch"),
    ("status", "Status"),
    ("owner", "Owner"),
    ("started", "Started"),
    ("updated", "Updated"),
    ("criteria", "Acceptance criteria"),
    ("mr", "MR"),
    ("ticket", "Ticket"),
]
LABEL = dict(SCALARS)
FIELD_OF = {v: k for k, v in SCALARS}
LISTS = [
    ("next", "Next"),
    ("done", "Done"),
    ("blockers", "Blockers"),
    ("decisions", "Decisions"),
]
SECTION_FIELD = {v: k for k, v in LISTS}
REQUIRED = [
    "task",
    "title",
    "branch",
    "status",
    "owner",
    "started",
    "updated",
    "criteria",
    "next",
]
MAX_LINES = 40  # the file must stay under this
TASK_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
DIR = os.path.join("docs", "progress")


def die(msg, code=2):
    print(f"progress: {msg}", file=sys.stderr)
    sys.exit(code)


def today():
    return datetime.datetime.now(datetime.timezone.utc).date().isoformat()


def git(root, *args):
    try:
        r = subprocess.run(
            ["git", "-C", root] + list(args), capture_output=True, text=True
        )
    except OSError:
        return None
    return r.stdout if r.returncode == 0 else None


def repo_root(given):
    if given:
        return given
    out = git(".", "rev-parse", "--show-toplevel")
    return out.strip() if out else os.getcwd()


def one_line(v):
    return re.sub(r"\s+", " ", v).strip()


def parse(text):
    """The fields of a progress file: scalars as strings, lists as lists."""
    rec = {}
    section = None
    for line in text.split("\n"):
        h = re.match(r"^## (.+?)\s*$", line)
        if h:
            section = h.group(1)
            if section in SECTION_FIELD:
                rec.setdefault(SECTION_FIELD[section], [])
            continue
        m = re.match(r"^- ([A-Za-z ]+): ?(.*)$", line)
        if m and m.group(1) in FIELD_OF and section in (None, "Links"):
            rec[FIELD_OF[m.group(1)]] = m.group(2).strip()
            continue
        b = re.match(r"^- (.*)$", line)
        if b and section in SECTION_FIELD:
            item = b.group(1).strip()
            if item and item != "none":
                rec[SECTION_FIELD[section]].append(item)
    return rec


def render(rec):
    tpl = open(TEMPLATE, encoding="utf-8").read()
    tpl = re.sub(r"[ \t]*<!--.*?-->[ \t]*\n?", "", tpl, flags=re.S)
    vals = {}
    for k, _ in SCALARS:
        vals[k] = rec.get(k) or "none"
    for k, _ in LISTS:
        items = rec.get(k) or []
        vals[k] = "\n".join("- " + i for i in items) if items else "- none"
    out = tpl
    for k, v in vals.items():
        out = out.replace("{" + k + "}", v)
    return out.rstrip("\n") + "\n"


def fit(rec):
    """Fold the oldest Done items until the file is under MAX_LINES."""
    text = render(rec)
    done = list(rec.get("done") or [])
    folded = 0
    if done and re.match(r"^\d+ earlier items", done[0]):
        folded = int(done[0].split()[0])
        done = done[1:]
    while text.count("\n") >= MAX_LINES and done:
        done.pop(0)
        folded += 1
        rec["done"] = [f"{folded} earlier items (see git log)"] + done
        text = render(rec)
    if text.count("\n") >= MAX_LINES:
        die(
            f"the file would be {text.count(chr(10))} lines (limit {MAX_LINES - 1}); shorten Blockers or Decisions",
            1,
        )
    return text


def cmd_write(a):
    if not TASK_RE.match(a.task):
        die(
            f"task id '{a.task}' has characters a file name cannot hold; use the branch name with / as _"
        )
    root = repo_root(a.root)
    path = os.path.join(root, DIR, a.task + ".md")
    created = not os.path.exists(path)
    if created:
        branch = (git(root, "branch", "--show-current") or "").strip() or "none"
        # The author of the latest commit, from the repository, before the
        # local git config: a machine's global name is not the task owner.
        owner = (
            (git(root, "log", "-1", "--format=%an") or "").strip()
            or (git(root, "config", "user.name") or "").strip()
            or os.environ.get("USER", "")
            or "unknown"
        )
        rec = {
            "task": a.task,
            "title": a.task,
            "branch": branch,
            "status": "started",
            "owner": owner,
            "started": today(),
            "criteria": "unknown",
            "next": [],
            "done": [],
            "blockers": [],
            "decisions": [],
        }
    else:
        rec = parse(open(path, encoding="utf-8").read())
    changed = []
    for k, _ in SCALARS:
        v = getattr(a, k, None)
        if v is not None and k != "task":
            v = one_line(v)
            if k == "status" and v not in STATUSES:
                die(f"unknown status '{v}'; one of: {', '.join(STATUSES)}")
            rec[k] = v
            changed.append(k)
    if a.next is not None:
        rec["next"] = [one_line(a.next)] if one_line(a.next) not in ("", "none") else []
        changed.append("next")
    for k, flag in (
        ("done", a.done),
        ("blockers", a.blocker),
        ("decisions", a.decision),
    ):
        if flag is not None:
            rec[k] = [one_line(x) for x in flag if one_line(x) not in ("", "none")]
            changed.append(k)
    for k, flag in (("done", a.add_done), ("decisions", a.add_decision)):
        for x in flag or []:
            x = one_line(x)
            if x and x != "none" and x not in rec.get(k, []):
                rec.setdefault(k, []).append(x)
            if k not in changed:
                changed.append(k)
    rec["task"] = a.task
    rec["updated"] = today()
    text = fit(rec)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    rel = os.path.relpath(path, root)
    print(
        f"progress: {'created' if created else 'updated'} {rel} "
        f"({text.count(chr(10))} lines, status {rec.get('status')}; "
        f"fields: {', '.join(changed) if changed else 'none'})"
    )
    return 0


def local_records(root):
    d = os.path.join(root, DIR)
    out = []
    if os.path.isdir(d):
        for n in sorted(os.listdir(d)):
            if n.endswith(".md"):
                p = os.path.join(d, n)
                out.append(
                    (os.path.relpath(p, root), n[:-3], open(p, encoding="utf-8").read())
                )
    return out


def ref_records(root):
    refs = (
        git(root, "for-each-ref", "--format=%(refname)", "refs/heads", "refs/remotes")
        or ""
    )
    out = []
    for ref in refs.split():
        if ref.endswith("/HEAD"):
            continue
        names = git(root, "ls-tree", "--name-only", ref, DIR + "/") or ""
        for p in names.split("\n"):
            if p.endswith(".md"):
                text = git(root, "show", f"{ref}:{p}")
                if text is not None:
                    out.append((f"{ref}:{p}", os.path.basename(p)[:-3], text))
    return out


def gather(root, refs):
    files = local_records(root)
    n_files = len(files)
    if refs:
        extra = ref_records(root)
        n_files += len(extra)
        files += extra
    best = {}
    for src, name, text in files:
        rec = parse(text)
        rec["_src"] = src
        key = rec.get("task") or name
        prev = best.get(key)
        if prev is None or (rec.get("updated") or "") > (prev.get("updated") or ""):
            best[key] = rec
    return n_files, [best[k] for k in sorted(best)]


def cmd_index(a):
    root = repo_root(a.root)
    n_files, recs = gather(root, a.refs)
    if n_files == 0:
        where = "the working tree or any branch" if a.refs else os.path.join(root, DIR)
        print(
            f"progress: 0 progress files in {where}; nothing to index (start-task writes one per task)",
            file=sys.stderr,
        )
        return 1
    if a.status and a.status not in STATUSES:
        die(f"unknown status '{a.status}'; one of: {', '.join(STATUSES)}")
    counts = {s: 0 for s in STATUSES}
    unknown = 0
    for r in recs:
        s = r.get("status", "")
        if s in counts:
            counts[s] += 1
        else:
            unknown += 1
    shown = [
        r
        for r in recs
        if (not a.status or r.get("status") == a.status)
        and (not a.open or r.get("status") not in CLOSED)
    ]
    rows = [("task", "status", "owner", "updated", "next")]
    for r in shown:
        nxt = (r.get("next") or ["none"])[0]
        rows.append(
            (
                r.get("task", "?"),
                r.get("status") or "?",
                r.get("owner") or "?",
                r.get("updated") or "?",
                nxt[:70],
            )
        )
    widths = [max(len(row[i]) for row in rows) for i in range(4)]
    for row in rows:
        print("  ".join(row[i].ljust(widths[i]) for i in range(4)) + "  " + row[4])
    parts = [f"{counts[s]} {s}" for s in STATUSES]
    if unknown:
        parts.append(f"{unknown} unknown status")
    tail = f"; {len(shown)} shown" if (a.status or a.open) else ""
    print(f"progress: {len(recs)} tasks ({', '.join(parts)}){tail}")
    return 0


def cmd_check(a):
    root = repo_root(a.root)
    files = local_records(root)
    if not files:
        print(
            f"progress check: 0 files in {os.path.join(root, DIR)}, nothing checked",
            file=sys.stderr,
        )
        return 1
    problems = []
    for src, name, text in files:
        rec = parse(text)
        for k in REQUIRED:
            v = rec.get(k)
            if k == "next" and rec.get("status") in CLOSED:
                continue  # a merged or abandoned task has no next action
            if not v or v == "none" or v == []:
                problems.append(f"{src}: missing {LABEL.get(k, k.capitalize())}")
        s = rec.get("status")
        if s and s not in STATUSES:
            problems.append(
                f"{src}: unknown status '{s}' (one of: {', '.join(STATUSES)})"
            )
        for k in ("started", "updated"):
            if rec.get(k) and not DATE_RE.match(rec[k]):
                problems.append(
                    f"{src}: {LABEL[k]} '{rec[k]}' is not a YYYY-MM-DD date"
                )
        if rec.get("task") and rec["task"] != name:
            problems.append(
                f"{src}: Task is {rec['task']} but the file is named {name}.md"
            )
        n = text.rstrip("\n").count("\n") + 1
        if n >= MAX_LINES:
            problems.append(f"{src}: {n} lines (limit {MAX_LINES - 1})")
    for p in problems:
        print(f"problem: {p}")
    print(f"progress check: {len(files)} files, {len(problems)} problems")
    return 1 if problems else 0


def main():
    ap = argparse.ArgumentParser(
        prog="progress.py", description="Per-task progress records in docs/progress/."
    )
    sub = ap.add_subparsers(dest="cmd")
    w = sub.add_parser("write")
    w.add_argument("--task", required=True)
    w.add_argument("--root")
    for k, _ in SCALARS:
        if k not in ("task", "started", "updated"):
            w.add_argument("--" + k)
    w.add_argument("--started")
    w.add_argument("--next")
    w.add_argument("--done", action="append")
    w.add_argument("--blocker", action="append")
    w.add_argument("--decision", action="append")
    w.add_argument("--add-done", action="append")
    w.add_argument("--add-decision", action="append")
    i = sub.add_parser("index")
    i.add_argument("--root")
    i.add_argument("--status")
    i.add_argument("--open", action="store_true")
    i.add_argument("--refs", action="store_true")
    c = sub.add_parser("check")
    c.add_argument("--root")
    a = ap.parse_args()
    if a.cmd == "write":
        a.updated = None  # always today
        return cmd_write(a)
    if a.cmd == "index":
        return cmd_index(a)
    if a.cmd == "check":
        return cmd_check(a)
    ap.print_usage(sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
