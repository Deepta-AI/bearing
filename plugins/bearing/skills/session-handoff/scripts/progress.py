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
      "none" clears it): --done --blocker --decision --repo ("<n>. <Name>
      (<path>)", at most 8; the file gets a "## Repos" section after Links
      only when the list is not empty). Appending:
      --add-done --add-decision (an item already present is not repeated).
      A file that would reach 40 lines folds the oldest Done items into one
      "N earlier items" line. --dry-run prints the file it would write and
      writes nothing. The SessionEnd hook runs write outside the sandbox, so
      docs and docs/progress are opened without following a link and the
      file is read only when it is a regular file with one link (a link, a
      FIFO or a hard link is refused, exit 1); the new text goes to a fresh
      temporary name that is then renamed over it, so nothing is ever
      written through a link.
  show --task ID [--root DIR]
      Prints docs/progress/<ID>.md, opened the same way as write; exit 3
      when there is none, 1 when it is not a regular file.
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

  set [--root DIR] --task ID
      For a task that spans repositories: reads the Repos list of this
      repository's docs/progress/<ID>.md and prints one row per repository,
      "<n>. <Name> <path>: ready | merged | not ready: <reason>", then
      "set: N repos, R ready, M merged, K not ready; merge order A, B, C".
      Not ready reasons, in this order: uncommitted changes, branch missing,
      then the gate: make check has never passed (marker missing), files
      newer than the last make check, 0 files on the branch. The row whose
      path is "." ends with "(this repository)". Exits 1 on no progress file,
      zero repositories or a missing path.

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
    ("repos", "Repos"),
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
REPO_RE = re.compile(r"^(\d+)\. ([A-Za-z0-9._-]+) \((.+)\)$")
MAX_REPOS = 8
MARKER = os.path.join(".bearing", "state", ".check-passed")


def die(msg, code=2):
    print(f"progress: {msg}", file=sys.stderr)
    sys.exit(code)


def today():
    return datetime.datetime.now(datetime.timezone.utc).date().isoformat()


def git(root, *args):
    try:
        r = subprocess.run(
            ["git", "--no-optional-locks", "-C", root] + list(args), capture_output=True, text=True
        )
    except OSError:
        return None
    return r.stdout if r.returncode == 0 else None


def repo_root(given):
    if given:
        return given
    out = git(".", "rev-parse", "--show-toplevel")
    return out.strip() if out else os.getcwd()


class NotRegular(Exception):
    """docs, docs/progress or the progress file is a link or not a regular file."""


DIRFLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
MAX_READ = 1048576


def progress_dir(root, create):
    """A descriptor of <root>/docs/progress, each part opened without following
    a link from the one before; None when absent and create is false."""
    d = os.open(root, os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in ("docs", "progress"):
            if create:
                try:
                    os.mkdir(part, 0o755, dir_fd=d)
                except FileExistsError:
                    pass
            try:
                n = os.open(part, DIRFLAGS, dir_fd=d)
            except FileNotFoundError:
                return None
            except OSError as e:
                raise NotRegular(f"{part} is a link or not a directory") from e
            os.close(d)
            d = n
        n, d = d, None
        return n
    finally:
        if d is not None:
            os.close(d)


def read_progress(dfd, name):
    """The text of <name> in dfd, or None when absent. A link, a FIFO, a
    directory or a file with a second hard link raises NotRegular; the open
    never blocks and never follows a link."""
    try:
        fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=dfd)
    except FileNotFoundError:
        return None
    except OSError as e:
        raise NotRegular("not a regular file") from e
    try:
        st = os.fstat(fd)
        if st.st_mode & 0o170000 != 0o100000 or st.st_nlink != 1:
            raise NotRegular("not a regular file")
        chunks, left = [], MAX_READ
        while left > 0:
            b = os.read(fd, min(65536, left))
            if not b:
                break
            chunks.append(b)
            left -= len(b)
        return b"".join(chunks).decode("utf-8")
    finally:
        os.close(fd)


def put_progress(dfd, name, text):
    """Write text to a fresh name (O_EXCL, never a link), then rename it over
    <name>: a rename replaces whatever sits at the name, never writes through it."""
    read_progress(dfd, name)  # refuses a link, a FIFO or a hard link at the name
    tmp = ".%s.%s.tmp" % (name[:64], os.urandom(8).hex())
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644, dir_fd=dfd)
    try:
        view = memoryview(text.encode("utf-8"))
        while view:
            view = view[os.write(fd, view):]
    finally:
        os.close(fd)
    try:
        os.rename(tmp, name, src_dir_fd=dfd, dst_dir_fd=dfd)
    except OSError:
        os.unlink(tmp, dir_fd=dfd)
        raise


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
        if k == "repos":
            continue
        items = rec.get(k) or []
        vals[k] = "\n".join("- " + i for i in items) if items else "- none"
    out = tpl
    for k, v in vals.items():
        out = out.replace("{" + k + "}", v)
    out = out.rstrip("\n") + "\n"
    if rec.get("repos"):
        out += "\n## Repos\n" + "\n".join("- " + i for i in rec["repos"]) + "\n"
    return out


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
    rel = os.path.join(DIR, a.task + ".md")
    name = a.task + ".md"
    dfd = None
    try:
        dfd = progress_dir(root, False)
        old = read_progress(dfd, name) if dfd is not None else None
    except NotRegular as e:
        print(f"progress: {rel}: {e}; not written", file=sys.stderr)
        return 1
    finally:
        if dfd is not None:
            os.close(dfd)
    created = old is None
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
        rec = parse(old)
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
        ("repos", a.repo),
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
    if a.dry_run:
        sys.stdout.write(text)
        return 0
    dfd = None
    try:
        dfd = progress_dir(root, True)
        put_progress(dfd, name, text)
    except NotRegular as e:
        print(f"progress: {rel}: {e}; not written", file=sys.stderr)
        return 1
    finally:
        if dfd is not None:
            os.close(dfd)
    print(
        f"progress: {'created' if created else 'updated'} {rel} "
        f"({text.count(chr(10))} lines, status {rec.get('status')}; "
        f"fields: {', '.join(changed) if changed else 'none'})"
    )
    return 0


def cmd_show(a):
    if not TASK_RE.match(a.task):
        die(f"task id '{a.task}' has characters a file name cannot hold")
    rel = os.path.join(DIR, a.task + ".md")
    dfd = None
    try:
        dfd = progress_dir(repo_root(a.root), False)
        text = read_progress(dfd, a.task + ".md") if dfd is not None else None
    except NotRegular as e:
        print(f"progress: {rel}: {e}", file=sys.stderr)
        return 1
    finally:
        if dfd is not None:
            os.close(dfd)
    if text is None:
        print(f"progress: no {rel}", file=sys.stderr)
        return 3
    sys.stdout.write(text)
    return 0


def base_ref(p):
    for b in ("origin/develop", "origin/main", "develop", "main"):
        if git(p, "rev-parse", "-q", "--verify", b + "^{commit}") is not None:
            return b
    return None


def gate(p, branch):
    """None when the gate passed after the last change, else the reason."""
    marker = os.path.join(p, MARKER)
    if not os.path.isfile(marker):
        return "make check has never passed"
    base = base_ref(p)
    names = set()
    if base:
        names.update((git(p, "diff", "--name-only", base + "..." + branch) or "").split("\n"))
    # -z: a name is never quoted; a rename or copy record is followed by the
    # old name, which is skipped. State files are newer than the marker by
    # construction; any other .bearing/ file counts.
    recs = (git(p, "status", "--porcelain", "-z", "--ignore-submodules=dirty", "--untracked-files=all") or "").split("\0")
    skip = False
    for rec in recs:
        if skip:
            skip = False
            continue
        if len(rec) > 3:
            names.add(rec[3:])
            skip = rec[0] in "RC"
    names = sorted(n for n in names if n and not n.startswith(".bearing/state/"))
    mt = os.path.getmtime(marker)
    stale = 0
    for n in names:
        f = os.path.join(p, n)
        if os.path.exists(f) and os.path.getmtime(f) > mt:
            stale += 1
    if stale:
        return f"{stale} of {len(names)} file(s) newer than the last make check"
    if not names:
        return "0 files on the branch"
    return None


def cmd_set(a):
    root = repo_root(a.root)
    path = os.path.join(root, DIR, a.task + ".md")
    if not os.path.isfile(path):
        print(f"set: no {DIR}/{a.task}.md in {root}", file=sys.stderr)
        return 1
    rec = parse(open(path, encoding="utf-8").read())
    branch = (git(root, "branch", "--show-current") or "").strip() or rec.get("branch", "")
    rows = []
    for item in rec.get("repos") or []:
        m = REPO_RE.match(item)
        if m:
            rows.append((m.group(1), m.group(2), m.group(3)))
    if not rows:
        print("set: 0 repos, nothing checked", file=sys.stderr)
        return 1
    ready = merged = bad = 0
    missing = False
    order = []
    for n, name, rp in rows:
        order.append(name)
        p = os.path.normpath(os.path.join(root, rp))
        tag = "  (this repository)" if rp == "." else ""
        if not os.path.exists(os.path.join(p, ".git")):
            print(f"{n}. {name} {rp}: missing{tag}")
            missing = True
            bad += 1
            continue
        other = os.path.join(p, DIR, a.task + ".md")
        status = ""
        if os.path.isfile(other):
            status = parse(open(other, encoding="utf-8").read()).get("status", "")
        if status == "merged":
            verdict = "merged"
            merged += 1
        elif git(p, "rev-parse", "-q", "--verify", "refs/heads/" + branch) is None:
            verdict = f"not ready: no branch {branch}"
            bad += 1
        else:
            dirty = [
                l
                for l in (git(p, "status", "--porcelain", "--ignore-submodules=dirty", "--untracked-files=no") or "").split("\n")
                if l
            ]
            reason = f"{len(dirty)} uncommitted" if dirty else gate(p, branch)
            if reason:
                verdict = "not ready: " + reason
                bad += 1
            else:
                verdict = "ready"
                ready += 1
        print(f"{n}. {name} {rp}: {verdict}{tag}")
    print(
        f"set: {len(rows)} repos, {ready} ready, {merged} merged, {bad} not ready; "
        f"merge order {', '.join(order)}"
    )
    return 1 if missing else 0


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
        items = rec.get("repos") or []
        if items:
            nums = []
            for it in items:
                m = REPO_RE.match(it)
                if m:
                    nums.append(int(m.group(1)))
                else:
                    problems.append(f'{src}: repos: item "{it}" is not "<n>. <Name> (<path>)"')
            if len(items) > MAX_REPOS:
                problems.append(f"{src}: repos: at most {MAX_REPOS} repositories in a set")
            if sorted(nums) != list(range(1, len(nums) + 1)):
                problems.append(f"{src}: repos: order numbers must be 1..N, each once")
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
    w.add_argument("--repo", action="append")
    w.add_argument("--add-done", action="append")
    w.add_argument("--add-decision", action="append")
    w.add_argument("--dry-run", action="store_true")
    sh = sub.add_parser("show")
    sh.add_argument("--task", required=True)
    sh.add_argument("--root")
    i = sub.add_parser("index")
    i.add_argument("--root")
    i.add_argument("--status")
    i.add_argument("--open", action="store_true")
    i.add_argument("--refs", action="store_true")
    st = sub.add_parser("set")
    st.add_argument("--root")
    st.add_argument("--task", required=True)
    c = sub.add_parser("check")
    c.add_argument("--root")
    a = ap.parse_args()
    if a.cmd == "write":
        a.updated = None  # always today
        return cmd_write(a)
    if a.cmd == "show":
        return cmd_show(a)
    if a.cmd == "index":
        return cmd_index(a)
    if a.cmd == "set":
        return cmd_set(a)
    if a.cmd == "check":
        return cmd_check(a)
    ap.print_usage(sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
