#!/usr/bin/env python3
"""docs_drift: which claims in a repository's docs no longer match the code,
checked mechanically and counted.

  - Docs: README.md, AGENTS.md and CLAUDE.md at the root and docs/**/*.md,
    minus docs/archive/, generated or vendored folders (node_modules, .git,
    dist, build, .venv, venv, vendor, target, coverage) and every --exclude
    glob. In a git repository the list comes from `git ls-files -co
    --exclude-standard`, so ignored files are never docs.
  - Broken (fails): a relative markdown link, image or href whose target
    does not exist; a backticked repository path that does not exist; a
    `make <target>` in a code span or fenced block that the root Makefile
    (and the files it includes) does not define.
  - Warnings: a backticked UPPER_SNAKE name (`DATABASE_URL`) found in no
    file outside the scanned docs (.env.example and .env.sample count);
    a doc whose referenced code saw --stale-after commits or more after the
    doc's own last commit (git log; skipped outside a git repository).
  - Conservative on purpose, since a false positive costs trust: URLs,
    anchors, placeholders (<x>, {x}, __X__, $X, NNNN, path/to), globs,
    spans with spaces, host-like first segments and gitignored paths are
    never flagged. A backticked path is only a claim when it starts with
    ./ or ../, names a known root file (Makefile, go.mod), ends in a known
    file extension, or its first segment is a directory that exists or a
    conventional source folder (src, internal, cmd). `make -C`, `make -f`
    and `cd x && make` point at another Makefile and are skipped.
  - History: in docs/adr/, docs/decisions/, docs/postmortems/ and
    docs/incidents/ a broken claim is a `history` warning (a dated record
    is correct for its date) and staleness is not computed.
  - Opt-outs: `<!-- docs-drift: ignore -->` on a line, or alone on the line
    before, silences that line; `<!-- docs-drift: ignore-file -->` anywhere
    skips the doc (counted as skipped).

Usage: docs_drift.py [--root DIR] [--strict] [--json] [--exclude GLOB]...
                     [--stale-after N]
Prints one "path:line: kind: detail" line per finding and the summary
"docs-drift: D docs checked, R references checked, B broken, W warnings".
Exits 1 when B > 0, when W > 0 under --strict, and when zero docs were
found. --json prints the same as one JSON object instead.
"""

import argparse
import bisect
import fnmatch
import json
import os
import re
import subprocess
import sys
from urllib.parse import unquote

ROOT_DOCS = ("README.md", "AGENTS.md", "CLAUDE.md")
SKIP_DIRS = {
    ".git",
    "node_modules",
    "dist",
    "build",
    ".venv",
    "venv",
    "vendor",
    "target",
    "coverage",
    "__pycache__",
    ".next",
    ".nuxt",
    ".tox",
    "site-packages",
}
KNOWN_FILES = {
    "Makefile", "GNUmakefile", "Dockerfile", "Procfile", "Justfile",
    "Taskfile.yml", "go.mod", "go.sum", "package.json", "package-lock.json",
    "pnpm-lock.yaml", "pnpm-workspace.yaml", "yarn.lock", "pyproject.toml",
    "uv.lock", "requirements.txt", "setup.py", "setup.cfg", "Cargo.toml",
    "Gemfile", "build.gradle", "build.gradle.kts", "settings.gradle.kts",
    "pom.xml", "tsconfig.json", "docker-compose.yml", "docker-compose.yaml",
    "compose.yml", "compose.yaml", ".env.example", ".env.sample",
    "README.md", "AGENTS.md", "CLAUDE.md", "CHANGELOG.md", "CONTRIBUTING.md",
    "SECURITY.md", "LICENSE", "CODEOWNERS", ".gitlab-ci.yml", ".gitignore",
    ".editorconfig", "VERSION",
}  # fmt: skip
KNOWN_DIRS = {
    "src", "internal", "cmd", "pkg", "app", "apps", "lib", "libs", "docs",
    "test", "tests", "scripts", "bin", "config", "configs", "deploy",
    "deployments", "migrations", "services", "packages", "tools", "web",
    "frontend", "backend", "server", "infra", "k8s", "helm", "charts",
    "terraform", ".github", ".gitlab",
}  # fmt: skip
KNOWN_EXT = {
    "py", "go", "ts", "tsx", "js", "jsx", "mjs", "cjs", "vue", "svelte",
    "md", "mdx", "yaml", "yml", "json", "toml", "ini", "cfg", "conf", "sh",
    "bash", "sql", "kt", "kts", "java", "swift", "rb", "rs", "c", "h", "cpp",
    "cs", "php", "html", "css", "scss", "txt", "csv", "proto", "tf", "tfvars",
    "graphql", "gql", "lock", "mod", "sum", "xml", "gradle", "env", "example",
    "sample", "dockerfile", "png", "svg", "jpg", "jpeg", "gif", "webp", "pdf",
}  # fmt: skip
STD_ENV = {
    "CLAUDE_PLUGIN_ROOT", "CLAUDE_PROJECT_DIR", "LD_LIBRARY_PATH", "LC_ALL",
    "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME",
    "GOOGLE_APPLICATION_CREDENTIALS", "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN", "AWS_REGION", "AWS_PROFILE",
    "AWS_DEFAULT_REGION", "NODE_OPTIONS", "NO_COLOR", "SSH_AUTH_SOCK",
}  # fmt: skip
STD_ENV_PREFIX = ("CI_", "GITHUB_", "GITLAB_", "RUNNER_")

FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})\s*([A-Za-z0-9_+-]*)")
CODE_SPAN = re.compile(r"(`+)(.+?)\1")
MD_LINK = re.compile(r"!?\[[^\]]*\]\(\s*(<[^>]*>|[^)\s]+)(?:\s+[\"'(][^)]*)?\)")
REF_DEF = re.compile(r"^\s{0,3}\[[^\]]+\]:\s*(<[^>]*>|\S+)")
HTML_REF = re.compile(
    r"""<(?:a|img|source)\b[^>]*?\b(?:href|src)\s*=\s*["']([^"']+)["']""", re.I
)
COMMENT = re.compile(r"<!--.*?-->")
SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
PATH_CHARS = re.compile(r"^[A-Za-z0-9._/+-]+$")
LINE_SUFFIX = re.compile(r"(?::\d+(?:[-:]\d+)?|#L\d+(?:-L?\d+)?)$")
PLACEHOLDER = re.compile(
    r"(?:^|[/._-])(?:N{2,}|n{3,}|X{2,}|x{3,}|YYYY|MM|DD)(?:$|[/._-])|__[A-Za-z0-9]+__|path/to|(?:^|/)(?:your|my)[-_]|(?:^|/)(?:foo|bar|baz|example)(?:$|[/.])"
)
ENV_SPAN = re.compile(r"^\$?\{?([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\}?(?:=\S*)?$")
# A command position: the start of a span or line, or after a shell separator.
CMD_SPLIT = re.compile(r"&&|\|\||[;|(`]|\$\(")
# What may stand before the command word: a prompt, a YAML list or run key,
# then/do, sudo/time/env, and VAR=value assignments.
CMD_LEAD = re.compile(r"^(?:[$>%]\s+|-\s+|(?:run|script|command):\s*|(?:then|do|sudo|time|env|exec)\s+|[A-Za-z_][A-Za-z0-9_]*=\S*\s+)+")
MAKE_TARGET = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*$")
# ADRs and postmortems are history: a broken claim in one is a warning.
HISTORY_DIRS = ("docs/adr/", "docs/decisions/", "docs/postmortems/", "docs/incidents/")
IGNORE_LINE = "docs-drift: ignore"
IGNORE_FILE = "docs-drift: ignore-file"


def run_git(root, args):
    try:
        p = subprocess.run(
            ["git", "-C", root] + args,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        return None
    return p.stdout.decode("utf-8", "replace") if p.returncode == 0 else None


def list_files(root):
    """(relative paths, is_git): tracked plus untracked-not-ignored in git."""
    if run_git(root, ["rev-parse", "--is-inside-work-tree"]) is not None:
        out = run_git(root, ["ls-files", "-co", "--exclude-standard", "-z"])
        if out is not None:
            files = [f for f in out.split("\0") if f]
            return [f for f in files if not skipped_dir(f)], True
    files = []
    for d, dirs, names in os.walk(root):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        rel = os.path.relpath(d, root)
        for n in names:
            files.append(n if rel == "." else os.path.join(rel, n).replace(os.sep, "/"))
    return files, False


def skipped_dir(rel):
    return any(part in SKIP_DIRS for part in rel.split("/")[:-1])


def is_doc(rel, excludes):
    if rel in ROOT_DOCS:
        pass
    elif rel.startswith("docs/") and rel.endswith(".md"):
        if rel.startswith("docs/archive/"):
            return False
    else:
        return False
    for g in excludes:
        if fnmatch.fnmatch(rel, g) or (g.endswith("/") and rel.startswith(g)):
            return False
    return True


def makefile_targets(root):
    """(targets, pattern regexes, dynamic) from the root Makefile and includes;
    None when there is no Makefile."""
    first = None
    for name in ("GNUmakefile", "makefile", "Makefile"):
        if os.path.isfile(os.path.join(root, name)):
            first = name
            break  # make's own order: the first one found wins
    if first is None:
        return None
    targets, patterns, dynamic = set(), [], False
    queue, seen = [first], set()
    while queue:
        rel = queue.pop()
        if rel in seen:
            continue
        seen.add(rel)
        try:
            text = open(
                os.path.join(root, rel), encoding="utf-8", errors="replace"
            ).read()
        except OSError:
            continue
        text = re.sub(r"\\\n", " ", text)
        for line in text.split("\n"):
            if line.startswith("\t") or line.lstrip().startswith("#"):
                continue
            inc = re.match(r"^\s*-?include\s+(.+)$", line)
            if inc:
                for g in inc.group(1).split():
                    if "$" in g:
                        dynamic = True
                        continue
                    for m in sorted(glob_rel(root, g)):
                        queue.append(m)
                continue
            m = re.match(r"^([^:=#\t][^:=#]*?)\s*::?(?!=)(.*)$", line)
            if not m:
                continue
            names = m.group(1).split()
            if names and names[0] in (".PHONY", ".DEFAULT_GOAL"):
                names = m.group(2).split("#")[0].split()
            for n in names:
                if "$" in n:
                    dynamic = True
                elif "%" in n:
                    patterns.append(
                        re.compile("^" + re.escape(n).replace("%", ".+") + "$")
                    )
                else:
                    targets.add(n)
    return targets, patterns, dynamic


def glob_rel(root, pattern):
    import glob

    base = os.path.join(root, pattern)
    return [os.path.relpath(p, root) for p in glob.glob(base) if os.path.isfile(p)]


class Checker:
    def __init__(self, root, files, is_git):
        self.root = root
        self.files = files
        self.is_git = is_git
        # every trailing run of segments, so `x/references/y.md` written
        # relative to an understood base (skills/) still counts as present
        self.suffixes = set()
        for f in files:
            segs = f.split("/")
            for k in range(len(segs)):
                self.suffixes.add("/".join(segs[k:]))
                if k < len(segs) - 1:
                    self.suffixes.add("/".join(segs[k:-1]) + "/")
        self.exists_cache = {}

    def exists(self, rel, want_dir=False):
        key = (rel, want_dir)
        if key not in self.exists_cache:
            p = os.path.join(self.root, rel)
            self.exists_cache[key] = os.path.isdir(p) if want_dir else os.path.exists(p)
        return self.exists_cache[key]


def resolve(doc, target):
    """Repository-relative path for a link target, or None when it leaves the root."""
    if target.startswith("/"):
        rel = target.lstrip("/")
    else:
        rel = os.path.normpath(os.path.join(os.path.dirname(doc), target))
    rel = rel.replace(os.sep, "/")
    if rel == "." or rel.startswith("../") or rel == "..":
        return None
    return rel


def link_target(raw):
    """The path part of a link target, or None when it is not a local path."""
    t = raw.strip()
    if t.startswith("<") and t.endswith(">"):
        t = t[1:-1].strip()
    if not t or t.startswith(("#", "//")) or SCHEME.match(t):
        return None
    t = t.split("#", 1)[0].split("?", 1)[0]
    if not t or re.search(r"[<>{}$*]|__[A-Za-z0-9]+__", t):
        return None
    return unquote(t)


def path_claim(span, checker, doc):
    """(candidates, is_dir) for a backticked span that claims a repository
    path, or None when it is not a claim we check."""
    s = LINE_SUFFIX.sub("", span.strip())
    if not s or not PATH_CHARS.match(s) or "//" in s or s in (".", "..", "/"):
        return None
    if s.startswith("/") or PLACEHOLDER.search(s):
        return None
    is_dir = s.endswith("/")
    body = s.rstrip("/")
    if body.startswith("./"):
        body = body[2:]
    relative = s.startswith(("./", "../"))
    doc_dir = os.path.dirname(doc)
    if "/" not in body:
        if body in KNOWN_FILES or (relative and has_known_ext(body)):
            return (
                [body, os.path.join(doc_dir, body) if doc_dir else body],
                is_dir,
                "bare",
            )
        return None
    first = body.split("/", 1)[0]
    last = body.rsplit("/", 1)[-1]
    if "." in first and not first.startswith(".") and first != "..":
        return None  # a host or module path (github.com/x/y)
    claim = (
        relative
        or has_known_ext(last)
        or first in KNOWN_DIRS
        or checker.exists(first, True)
        or (doc_dir and checker.exists(os.path.join(doc_dir, first), True))
    )
    if not claim:
        return None
    cands = []
    if not body.startswith("../"):
        cands.append(body)
    r = resolve(doc, body)
    if r and r not in cands and doc_dir:
        cands.append(r)
    if not cands:
        return None
    return cands, is_dir, "path"


def has_known_ext(name):
    m = re.search(r"\.([A-Za-z0-9]+)$", name)
    return bool(m) and m.group(1).lower() in KNOWN_EXT


def make_targets_in(code):
    """Target names from each `make ...` invocation in a code line."""
    out = []
    if re.search(r"\bcd\s+\S+\s*(?:&&|;)\s*make\b", code):
        return out
    for seg in CMD_SPLIT.split(code):
        seg = CMD_LEAD.sub("", seg.strip())
        words = seg.split()
        if len(words) < 2 or words[0] != "make":
            continue
        args = words[1:]
        names = []
        for a in args:
            if a in ("&&", "||", "|", ";", ">", "2>&1") or a.startswith(
                ("#", ">", "<")
            ):
                break
            if a.startswith("-"):
                if a in ("-C", "-f", "--file", "--directory") or a.startswith(
                    ("-C", "-f", "--file=", "--directory=")
                ):
                    names = None
                    break
                continue
            if "=" in a:
                continue
            a = a.rstrip(";,.)`")
            if not MAKE_TARGET.match(a):
                break
            names.append(a)
        if names:
            out.extend(names)
    return out


def scan_doc(doc, text, checker, make, env_refs, path_refs, findings, counts):
    lines = text.split("\n")
    in_fence, fence_mark, fence_lang = False, "", ""
    ignore_next = False
    for i, line in enumerate(lines, 1):
        ignore = ignore_next or IGNORE_LINE in line.replace(IGNORE_FILE, "")
        ignore_next = (
            line.strip().startswith("<!--")
            and line.strip().endswith("-->")
            and IGNORE_LINE in line
        )
        f = FENCE.match(line)
        if f and (
            not in_fence
            or f.group(1)[0] == fence_mark[0]
            and len(f.group(1)) >= len(fence_mark)
        ):
            if in_fence:
                in_fence = False
            else:
                in_fence, fence_mark, fence_lang = True, f.group(1), f.group(2).lower()
            continue
        if in_fence:
            if make is not None and fence_lang not in (
                "mermaid",
                "markdown",
                "md",
                "diff",
            ):
                code = line.split(" #", 1)[0]
                if not code.lstrip().startswith("#"):
                    for t in make_targets_in(code):
                        check_make(doc, i, t, make, findings, counts, ignore)
            continue

        spans = [m.group(2).strip() for m in CODE_SPAN.finditer(line)]
        prose = COMMENT.sub("", CODE_SPAN.sub("", line))
        for s in spans:
            if make is not None:
                for t in make_targets_in(s):
                    check_make(doc, i, t, make, findings, counts, ignore)
            env = ENV_SPAN.match(s)
            if env:
                name = env.group(1)
                if name not in STD_ENV and not name.startswith(STD_ENV_PREFIX):
                    counts["refs"] += 1
                    env_refs.setdefault(name, []).append((doc, i, ignore))
                continue
            claim = path_claim(s, checker, doc)
            if claim is None:
                continue
            cands, is_dir, how = claim
            counts["refs"] += 1
            hit = None
            for c in cands:
                if checker.exists(c, is_dir):
                    hit = c
                    break
            if hit is not None:
                path_refs.add(hit + ("/" if is_dir else ""))
            elif cands[0] + ("/" if is_dir else "") in checker.suffixes:
                pass  # present under an understood base; not an exact path to date
            else:
                add(
                    findings,
                    doc,
                    i,
                    "broken-path",
                    f"`{s}` does not exist",
                    ignore,
                    cands[0],
                )
        targets = [m.group(1) for m in MD_LINK.finditer(prose)]
        targets += [m.group(1) for m in HTML_REF.finditer(line)]
        r = REF_DEF.match(prose)
        if r:
            targets.append(r.group(1))
        for raw in targets:
            t = link_target(raw)
            if t is None:
                continue
            rel = resolve(doc, t)
            if rel is None:
                continue
            counts["refs"] += 1
            if checker.exists(rel):
                path_refs.add(rel + ("/" if checker.exists(rel, True) else ""))
            else:
                add(
                    findings,
                    doc,
                    i,
                    "broken-link",
                    f"({t}) resolves to {rel}, which does not exist",
                    ignore,
                    rel,
                )


def check_make(doc, line, target, make, findings, counts, ignore):
    targets, patterns, dynamic = make
    counts["refs"] += 1
    if target in targets or any(p.match(target) for p in patterns):
        return
    if dynamic:
        add(
            findings,
            doc,
            line,
            "make-unverified",
            f"make {target}: not a literal target; the Makefile builds some target names from variables",
            ignore,
            severity="warning",
        )
    else:
        add(
            findings,
            doc,
            line,
            "broken-make",
            f"make {target}: no such target in the Makefile",
            ignore,
        )


def add(findings, doc, line, kind, detail, ignore, missing=None, severity="broken"):
    if ignore:
        return
    if severity == "broken" and doc.startswith(HISTORY_DIRS):
        # correct for its date; reported, never failed, never "fixed"
        kind, severity = "history", "warning"
        detail = detail + " (a dated record: not rewritten)"
    findings.append(
        {
            "path": doc,
            "line": line,
            "kind": kind,
            "severity": severity,
            "detail": detail,
            "missing": missing,
        }
    )


def drop_ignored(root, findings, is_git):
    """A missing path git ignores (.env, bin/app) is local output, not drift."""
    if not is_git:
        return findings
    missing = sorted({f["missing"] for f in findings if f.get("missing")})
    if not missing:
        return findings
    try:
        p = subprocess.run(
            ["git", "-C", root, "check-ignore", "--no-index", "--stdin"],
            input="\n".join(missing).encode(),
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        ignored = set(p.stdout.decode("utf-8", "replace").split("\n"))
    except OSError:
        return findings
    return [f for f in findings if not f.get("missing") or f["missing"] not in ignored]


def env_findings(root, files, docs, env_refs, findings):
    if not env_refs:
        return
    doc_set = set(docs)
    todo = set(env_refs)
    rx = re.compile(
        r"\b(" + "|".join(sorted(map(re.escape, todo), key=len, reverse=True)) + r")\b"
    )
    for rel in files:
        if not todo:
            break
        if rel in doc_set:
            continue
        p = os.path.join(root, rel)
        try:
            if os.path.getsize(p) > 2000000:
                continue
            data = open(p, "rb").read()
        except OSError:
            continue
        if b"\0" in data[:4096]:
            continue
        for m in rx.finditer(data.decode("utf-8", "replace")):
            todo.discard(m.group(1))
    for name in sorted(todo):
        for doc, line, ignore in env_refs[name]:
            add(
                findings,
                doc,
                line,
                "env-unused",
                f"`{name}` appears in no code, config or .env.example",
                ignore,
                severity="warning",
            )


def stale_findings(root, docs, refs_by_doc, threshold, findings):
    """Commits (newest first, index 0) touching each referenced path after the
    doc's own last commit; one warning per doc at or over the threshold."""
    out = run_git(
        root,
        [
            "log",
            "--no-merges",
            "--relative",
            "--name-only",
            "--format=%x00%h",
            "-n",
            "20000",
        ],
    )
    if out is None:
        return
    touched = {}  # path -> commit indices, ascending
    shas = []
    for idx, chunk in enumerate(out.split("\0")[1:]):
        parts = chunk.strip().split("\n")
        shas.append(parts[0])
        for f in parts[1:]:
            f = f.strip()
            if not f:
                continue
            touched.setdefault(f, []).append(idx)
            segs = f.split("/")
            for k in range(1, len(segs)):
                touched.setdefault("/".join(segs[:k]) + "/", []).append(idx)
    for key in touched:
        touched[key] = sorted(set(touched[key]))
    for doc in docs:
        own = touched.get(doc)
        if not own:
            continue  # never committed: being written now
        cut = own[0]
        commits, per = set(), []
        for ref in sorted(refs_by_doc.get(doc, ())):
            if ref.endswith(".md") or ref.startswith("docs/") or ref == doc:
                continue
            idx = touched.get(ref, [])
            newer = idx[: bisect.bisect_left(idx, cut)]
            if newer:
                commits.update(newer)
                per.append((len(newer), ref))
        if len(commits) >= threshold:
            per.sort(key=lambda x: (-x[0], x[1]))
            top = ", ".join(f"{r} {n}" for n, r in per[:3])
            add(
                findings,
                doc,
                1,
                "stale",
                f"{len(commits)} commits touched referenced paths after the doc's last commit {shas[cut]} ({top})",
                False,
                severity="warning",
            )


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--strict", action="store_true", help="warnings fail too")
    ap.add_argument("--json", action="store_true", help="print one JSON object")
    ap.add_argument("--exclude", action="append", default=[], metavar="GLOB")
    ap.add_argument(
        "--stale-after",
        type=int,
        default=5,
        metavar="N",
        help="commits after the doc that make it stale (default 5)",
    )
    a = ap.parse_args()
    root = os.path.abspath(a.root)
    if not os.path.isdir(root):
        print(
            f"docs-drift: --root {a.root} is not a directory, nothing checked",
            file=sys.stderr,
        )
        return 1

    files, is_git = list_files(root)
    docs = sorted(f for f in files if is_doc(f, a.exclude))
    checker = Checker(root, files, is_git)
    make = makefile_targets(root)
    findings, env_refs, refs_by_doc = [], {}, {}
    counts = {"refs": 0}
    checked, skipped = [], 0
    for doc in docs:
        try:
            text = open(
                os.path.join(root, doc), encoding="utf-8", errors="replace"
            ).read()
        except OSError:
            continue
        if IGNORE_FILE in text:
            skipped += 1
            continue
        checked.append(doc)
        refs = set()
        scan_doc(doc, text, checker, make, env_refs, refs, findings, counts)
        refs_by_doc[doc] = refs
    findings = drop_ignored(root, findings, is_git)
    env_findings(root, files, docs, env_refs, findings)
    if is_git:
        current = [d for d in checked if not d.startswith(HISTORY_DIRS)]
        stale_findings(root, current, refs_by_doc, max(1, a.stale_after), findings)

    findings.sort(key=lambda f: (f["path"], f["line"], f["kind"], f["detail"]))
    broken = sum(1 for f in findings if f["severity"] == "broken")
    warnings = len(findings) - broken
    summary = f"docs-drift: {len(checked)} docs checked, {counts['refs']} references checked, {broken} broken, {warnings} warnings"
    if a.json:
        for f in findings:
            f.pop("missing", None)
        print(json.dumps({
            "root": root, "docs": len(checked), "skipped": skipped,
            "references": counts["refs"], "broken": broken, "warnings": warnings,
            "strict": a.strict, "makefile": make is not None, "git": is_git,
            "findings": findings,
        }, indent=1))  # fmt: skip
    else:
        for f in findings:
            print(f"{f['path']}:{f['line']}: {f['kind']}: {f['detail']}")
        if skipped:
            print(f"docs-drift: {skipped} docs skipped by {IGNORE_FILE}")
        print(summary)
    if not checked:
        print(
            f"docs-drift: 0 docs found under {root} (README.md, AGENTS.md, CLAUDE.md, docs/**/*.md), nothing checked",
            file=sys.stderr,
        )
        return 1
    return 1 if broken or (a.strict and warnings) else 0


if __name__ == "__main__":
    sys.exit(main())
