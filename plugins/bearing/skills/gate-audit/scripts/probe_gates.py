#!/usr/bin/env python3
"""probe_gates: run every gate twice, once on empty input and once on a copy
of the repository as it is, and read the CI file and hooks for what keeps a
gate from blocking. The repository itself is never written.

Gates found:
  - make: the prerequisites of `check` in the root Makefile and the words
    of its GATES variable (`check` itself when it has no prerequisites).
  - CI: every `make <targets>` at a command position in .gitlab-ci.yml,
    .github/workflows/*.y*ml, .circleci/config.yml, bitbucket-pipelines.yml
    or Jenkinsfile, named by the job it sits under. A target already found
    is probed once.
  - hooks: the git hooks (pre-commit, commit-msg, pre-push,
    prepare-commit-msg, pre-merge-commit, pre-rebase) in .githooks/ or
    .husky/. lefthook.yml and .pre-commit-config.yaml are listed as not
    probed (a runner config; probe the commands it runs through make).

Runs, per make gate, each with --timeout seconds (default 120),
network-offline variables for Go, npm, pip and uv, killed with its process
group on timeout:
  - empty: a fresh temporary directory with the Makefile, its includes and
    *.mk files, root tool configs, and each script the dry run
    (`make -n <target>`) invokes, with the sibling files that script names.
    A directory the dry run names is created empty; everything else, the
    gate's input, is left out. node_modules, .venv and vendor are
    symlinked. `git init` with the kept files excluded, then
    `make -s <target>`. The dry run itself runs in the repository, so a
    recipe line make executes under -n ($(MAKE), a + prefix, $(shell))
    does run there.
  - repository: one copy of every tracked and unignored file, git-initialised
    with all of it staged, shared by the gates in order (skip with
    --empty-only). The count column comes from this run: a gate that
    prints a count only on real input still counts. Problems: it fails
    here, it reports zero items, or its output is the same as on empty
    input (nothing shows it examined anything).
  - hooks: the hook directory and the Makefile in an empty `git init`
    repository with nothing staged; commit-msg gets an empty message file,
    pre-push an empty ref list. Read for `git add` (re-staging commits
    unstaged hunks) and an unconditional final `exit 0`.

Read, not run: exit-code escapes in a recipe or CI script (`|| true`,
`|| [ $? -eq 5 ]`, `|| exit 0`, `set +e`, `xargs -r`, a `-` recipe prefix);
per CI job, allow_failure, continue-on-error, when: manual and a changes or
paths rule with the number of repository files it matches; each make check
prerequisite that no blocking, unrestricted CI job runs; and for each hook
directory, core.hooksPath in this clone and which tracked file sets it
(a Makefile, script or package.json) or only documents it.

Not probed, with the reason: a dry run or hook that names docker, a
cloud or cluster CLI, curl, wget, ssh, a database client, gh or glab, a
package install, git push/fetch/pull/clone, npx, DATABASE_URL, deploy or
publish; a CI target the root Makefile lacks; a dry run that fails; a
timeout.

A count is a line of output holding a number followed by a word ("0
files", "12 packages") or the words "nothing checked".

Usage: probe_gates.py [--repo .] [--only NAME] [--timeout S] [--empty-only]
Prints a "gate:" line per gate, a "ci-job:" line per CI job, a "hooks:"
line per hook directory, a "problem:" line per finding, a "not probed:"
line per gate skipped, and the counts; exits 1 on any problem, or when
zero gates were found or zero were probed.
"""

import argparse
import glob
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile

HOOK_NAMES = (
    "pre-commit",
    "commit-msg",
    "pre-push",
    "prepare-commit-msg",
    "pre-merge-commit",
    "pre-rebase",
)
CI_FILES = [
    ".gitlab-ci.yml",
    ".circleci/config.yml",
    "bitbucket-pipelines.yml",
    "Jenkinsfile",
]
CONFIGS = [
    "package.json",
    "go.mod",
    "go.sum",
    "pyproject.toml",
    "setup.cfg",
    "tox.ini",
    "ruff.toml",
    ".ruff.toml",
    "mypy.ini",
    ".golangci.yml",
    ".golangci.yaml",
    ".eslintrc",
    ".eslintrc.json",
    ".eslintrc.js",
    "eslint.config.js",
    "eslint.config.mjs",
    ".prettierrc",
    ".prettierrc.json",
    "biome.json",
    ".editorconfig",
    ".shellcheckrc",
    ".swiftlint.yml",
    ".swiftformat",
    "Cargo.toml",
    "Cargo.lock",
    "pnpm-lock.yaml",
    "package-lock.json",
    "yarn.lock",
    "uv.lock",
    "poetry.lock",
    ".nvmrc",
    ".tool-versions",
]
CONFIG_GLOBS = [
    "tsconfig*.json",
    "vitest.config.*",
    "jest.config.*",
    "playwright.config.*",
    "*.mk",
]
DEP_DIRS = ["node_modules", ".venv", "vendor"]
SCRIPT_EXT = (".sh", ".bash", ".py", ".mjs", ".cjs", ".js", ".ts", ".rb", ".pl")
UNSAFE = re.compile(
    r"\b(docker|docker-compose|podman|kubectl|helm|terraform|tofu|pulumi|curl|wget|ssh|scp|rsync|psql|mysql|"
    r"redis-cli|mongosh|gh|glab|npx|aws|gcloud|az|DATABASE_URL|deploy|publish)\b"
    r"|\bgit\s+(push|fetch|pull|clone)\b|\b(npm|pnpm|yarn)\s+(install|ci|add|dlx)\b|\bpip3?\s+install\b"
    r"|\buv\s+(sync|add|pip\s+install)\b|\bgo\s+(mod\s+download|install|get)\b"
)
INVOKERS = {
    "bash",
    "sh",
    "zsh",
    "python",
    "python3",
    "node",
    "ruby",
    "perl",
    "source",
    ".",
    "exec",
}
COUNT = re.compile(r"\b\d+\s+[A-Za-z]")
OFFLINE = {
    "GOPROXY": "off",
    "GOFLAGS": "-mod=mod",
    "GOTOOLCHAIN": "local",
    "npm_config_offline": "true",
    "PIP_NO_INDEX": "1",
    "UV_OFFLINE": "1",
    "YARN_ENABLE_NETWORK": "0",
    "BEARING_PROBE": "1",
}


def read(p):
    try:
        return open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def makefile(repo):
    # Compare names from the directory listing: on a case-insensitive disk
    # (macOS APFS) isfile("makefile") is true for a Makefile, and the report
    # would name a file that is not there.
    try:
        names = set(os.listdir(repo))
    except OSError:
        return None
    for n in ("GNUmakefile", "makefile", "Makefile"):
        if n in names and os.path.isfile(os.path.join(repo, n)):
            return n
    return None


def make_gates(repo, mk):
    text = read(os.path.join(repo, mk))
    words = []
    m = re.search(r"^check:([^#\n]*)", text, re.M)
    if m:
        words += m.group(1).split()
    g = re.search(r"^GATES\s*:?=\s*(.*)$", text, re.M)
    if g:
        words += g.group(1).split()
    words = [w for w in dict.fromkeys(words) if not w.startswith("$")]
    if m and not words:
        words = ["check"]
    return words


GITLAB_RESERVED = {
    "stages",
    "variables",
    "default",
    "include",
    "workflow",
    "image",
    "services",
    "before_script",
    "after_script",
    "cache",
}
MAKE_CALL = re.compile(
    r"(?:^\s*(?:-\s+)?(?:run:\s*)?|&&\s*|;\s*|\|\|\s*)make((?:\s+[A-Za-z0-9_$-][^\s;&|]*)+)"
)
ESCAPE = re.compile(
    r"\|\|\s*(?:true\b|:(?=\s|$|\))|exit\s+0\b|\[\s*\$\$?\?\s*-eq\s*\d+\s*\])|\bset\s+\+e\b"
    r"|\bxargs\s+(?:-r|--no-run-if-empty)\b"
)


def ci_files(repo):
    files = [f for f in CI_FILES if os.path.isfile(os.path.join(repo, f))]
    files += sorted(
        os.path.relpath(p, repo)
        for p in glob.glob(os.path.join(repo, ".github/workflows/*.y*ml"))
    )
    return files


def list_items(lines, i, indent):
    """The `- item` values nested under lines[i] (deeper than indent)."""
    out = []
    for line in lines[i + 1 :]:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        ind = len(line) - len(line.lstrip())
        if ind <= indent:
            break
        m = re.match(r"^\s*-\s+[\"']?([^\"'#\s]+)", line)
        if m:
            out.append(m.group(1))
    return out


def ci_jobs(repo):
    """Each CI job: file, name, make targets, and what keeps it from blocking."""
    jobs = []
    for f in ci_files(repo):
        lines = read(os.path.join(repo, f)).split("\n")
        github = f.startswith(".github/")
        job, in_jobs, wf_paths = None, False, []
        for i, line in enumerate(lines):
            if line.lstrip().startswith("#"):
                continue
            ind = len(line) - len(line.lstrip())
            if github:
                if re.match(r"^jobs:\s*$", line):
                    in_jobs = True
                if not in_jobs and re.match(r"^\s+paths:\s*$", line):
                    wf_paths += list_items(lines, i, ind)
                j = re.match(r"^  ([A-Za-z0-9_.-]+):\s*$", line) if in_jobs else None
            else:
                j = re.match(r"^([^\s#][^#]*?):\s*$", line)
            if j:
                name = j.group(1)
                job = {
                    "file": f,
                    "name": name,
                    "targets": [],
                    "nonblocking": [],
                    "changes": list(wf_paths) if github else [],
                    "escapes": [],
                    "real": github
                    or not (name in GITLAB_RESERVED or name.startswith(".")),
                }
                jobs.append(job)
                continue
            if job is None:
                continue
            if re.match(r"^\s+allow_failure:\s*true\b", line):
                job["nonblocking"].append("allow_failure: true")
            if re.match(r"^\s+continue-on-error:\s*true\b", line):
                job["nonblocking"].append("continue-on-error: true")
            if re.match(r"^\s+-?\s*when:\s*manual\b", line):
                job["nonblocking"].append("when: manual")
            if re.match(r"^\s+-?\s*changes:\s*$", line):
                job["changes"] += [
                    c for c in list_items(lines, i, ind) if c != "paths:"
                ]
            for m in MAKE_CALL.finditer(line):
                for t in m.group(1).split():
                    if re.match(r"^[A-Za-z0-9_][A-Za-z0-9_.-]*$", t):
                        job["targets"].append(t)
            e = ESCAPE.search(line)
            if e:
                job["escapes"].append(e.group(0).strip())
    return [j for j in jobs if j["real"]]


def glob_re(pat):
    out, i = "", 0
    while i < len(pat):
        if pat.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pat.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pat[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pat[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pat[i]), i + 1
    return re.compile("^" + out + "$")


def tracked(repo):
    """The repository's files: git's tracked and unignored list, else a walk."""
    r = subprocess.run(
        ["git", "-C", repo, "ls-files", "-co", "--exclude-standard"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    if r.returncode == 0 and r.stdout.strip():
        return [p for p in r.stdout.split("\n") if p]
    out = []
    for root, dirs, files in os.walk(repo):
        dirs[:] = [d for d in dirs if d != ".git" and d not in DEP_DIRS]
        for n in files:
            out.append(os.path.relpath(os.path.join(root, n), repo))
    return sorted(out)


def hook_gates(repo):
    out, runners = [], []
    for d in (".githooks", ".husky"):
        for n in HOOK_NAMES:
            if os.path.isfile(os.path.join(repo, d, n)):
                out.append((f"{d}/{n}", d))
    for r in ("lefthook.yml", ".pre-commit-config.yaml"):
        if os.path.isfile(os.path.join(repo, r)):
            runners.append(r)
    return out, runners


def run(cmd, cwd, timeout, stdin=""):
    env = dict(os.environ)
    env.update(OFFLINE)
    env["GIT_CEILING_DIRECTORIES"] = os.path.dirname(cwd)
    p = subprocess.Popen(
        cmd,
        cwd=cwd,
        env=env,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=True,
    )
    try:
        out, _ = p.communicate(stdin, timeout=timeout)
        return p.returncode, out
    except subprocess.TimeoutExpired:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except OSError:
            pass
        p.communicate()
        return None, ""


def invoked_paths(text, repo):
    """(files, dirs) the dry run names: invoked scripts and directories."""
    files, dirs = set(), set()
    for seg in re.split(r"[;&|()`\n]+|\$\(", text):
        toks = [t.strip("\"'{}") for t in seg.split()]
        for i, t in enumerate(toks):
            p = t[2:] if t.startswith("./") else t
            if not p or p.startswith(("-", "/", "$")):
                continue
            full = os.path.join(repo, p)
            if os.path.isdir(full) and p not in (".", ".."):
                dirs.add(p.rstrip("/"))
            elif os.path.isfile(full):
                prev = toks[i - 1] if i else ""
                first = i == 0 or (i == 1 and toks[0] in ("@", "-", "+", "exec"))
                lead = i == 1 or (i == 2 and toks[0] in ("@", "-", "+"))
                if (prev in INVOKERS and (prev not in (".", "source") or lead)) or (
                    first and os.access(full, os.X_OK)
                ):
                    files.add(p)
    return files, dirs


def copy(repo, tmp, rel):
    src, dst = os.path.join(repo, rel), os.path.join(tmp, rel)
    os.makedirs(os.path.dirname(dst) or tmp, exist_ok=True)
    shutil.copy2(src, dst)


def build_copy(repo, mk, dry):
    tmp = tempfile.mkdtemp(prefix="brg-probe-")
    kept = [mk]
    copy(repo, tmp, mk)
    for inc in re.findall(r"^-?include\s+(.+)$", read(os.path.join(repo, mk)), re.M):
        for p in inc.split():
            if os.path.isfile(os.path.join(repo, p)):
                copy(repo, tmp, p)
                kept.append(p)
    for c in CONFIGS:
        if os.path.isfile(os.path.join(repo, c)):
            copy(repo, tmp, c)
            kept.append(c)
    for g in CONFIG_GLOBS:
        for p in glob.glob(os.path.join(repo, g)):
            rel = os.path.relpath(p, repo)
            if rel not in kept:
                copy(repo, tmp, rel)
                kept.append(rel)
    files, dirs = invoked_paths(dry, repo)
    for f in sorted(files):
        copy(repo, tmp, f)
        kept.append(f)
        d = os.path.dirname(f)
        body = read(os.path.join(repo, f))
        for sib in os.listdir(os.path.join(repo, d) if d else repo):
            rel = os.path.join(d, sib) if d else sib
            if rel in kept or not os.path.isfile(os.path.join(repo, rel)):
                continue
            stem = os.path.splitext(sib)[0]
            if sib.endswith(SCRIPT_EXT) and (
                sib in body
                or re.search(
                    r"\bimport\s+"
                    + re.escape(stem)
                    + r"\b|\bfrom\s+"
                    + re.escape(stem)
                    + r"\b",
                    body,
                )
            ):
                copy(repo, tmp, rel)
                kept.append(rel)
    for d in sorted(dirs):
        if d not in DEP_DIRS:
            os.makedirs(os.path.join(tmp, d), exist_ok=True)
    for d in DEP_DIRS:
        if os.path.isdir(os.path.join(repo, d)) and not os.path.exists(
            os.path.join(tmp, d)
        ):
            os.symlink(os.path.join(os.path.abspath(repo), d), os.path.join(tmp, d))
    return tmp, kept


def git_init(tmp, kept=()):
    """An empty repository whose kept machinery git does not list."""
    subprocess.run(
        ["git", "init", "-q", tmp], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    excl = os.path.join(tmp, ".git", "info", "exclude")
    if kept and os.path.isdir(os.path.dirname(excl)):
        with open(excl, "a", encoding="utf-8") as fh:
            fh.write("".join("/" + k + "\n" for k in kept))


def count_line(out):
    for line in out.split("\n"):
        if COUNT.search(line) or "nothing checked" in line:
            return line.strip()[:120]
    return None


def recipe(repo, mk, target):
    """The recipe lines of target in the root Makefile, as written."""
    out, on = [], False
    for line in read(os.path.join(repo, mk)).split("\n"):
        if re.match(r"^" + re.escape(target) + r"\s*:(?!=)", line):
            on = True
            continue
        if on:
            if line.startswith("\t"):
                out.append(line[1:])
            elif line.strip() and not line.startswith("#"):
                break
    return out


def escapes(lines):
    found = []
    for line in lines:
        if re.match(r"^[@+]*-", line):
            found.append("- prefix (make ignores the exit code)")
        e = ESCAPE.search(line)
        if e:
            found.append(e.group(0).strip().replace("$$", "$"))
    return list(dict.fromkeys(found))


def build_real(repo):
    """A copy of the repository as it is, git-initialised with every file staged."""
    tmp = tempfile.mkdtemp(prefix="brg-probe-real-")
    n = 0
    for rel in tracked(repo):
        src = os.path.join(repo, rel)
        if rel.split("/")[0] in DEP_DIRS or not os.path.lexists(src):
            continue
        if os.path.isdir(src) and not os.path.islink(src):
            continue
        dst = os.path.join(tmp, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst, follow_symlinks=False)
        n += 1
    for d in DEP_DIRS:
        if os.path.isdir(os.path.join(repo, d)):
            os.symlink(os.path.join(repo, d), os.path.join(tmp, d))
    git_init(tmp, [d for d in DEP_DIRS])
    subprocess.run(
        ["git", "-C", tmp, "add", "-A"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return tmp, n


def same(a, b):
    def norm(t):
        return re.sub(r"\d+(\.\d+)?m?s\b", "T", t).strip()

    return norm(a) == norm(b)


ZERO = re.compile(r"(?<![\d.])0\s+[A-Za-z]|no tests ran|collected 0 items|matched no packages")


def probe_make(repo, mk, target, timeout, real_dir):
    rc, dry = run(["make", "-n", target], repo, min(timeout, 60))
    if rc is None:
        return {"skip": "make -n timed out"}
    if rc != 0 and "No rule to make target" in dry:
        return {"skip": f"no target {target} in the root Makefile (the job may run it in another directory)"}
    if rc != 0:
        return {
            "skip": f"make -n {target} failed: {dry.strip().splitlines()[-1][:100] if dry.strip() else 'no output'}"
        }
    u = UNSAFE.search(dry)
    if u:
        return {"skip": f"needs network or a service ({u.group(0).strip()})"}
    tmp, kept = build_copy(repo, mk, dry)
    try:
        git_init(tmp, kept + [d for d in DEP_DIRS])
        rc, out = run(["make", "-s", "--no-print-directory", target], tmp, timeout)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if rc is None:
        return {"skip": f"timed out after {timeout}s on empty input"}
    res = {
        "rc": rc,
        "count": count_line(out),
        "kept": kept,
        "escapes": escapes(recipe(repo, mk, target) + dry.split("\n")),
    }
    if real_dir:
        rrc, rout = run(["make", "-s", "--no-print-directory", target], real_dir, timeout)
        res.update(
            real_rc=rrc,
            real_count=count_line(rout) if rrc is not None else None,
            real_last=(rout.strip().splitlines() or [""])[-1][:100],
            real_zero=bool(rrc == 0 and ZERO.search(rout)),
            real_same=bool(rrc == 0 and rc == 0 and same(out, rout)),
        )
    return res


def probe_hook(repo, hook, timeout):
    text = read(os.path.join(repo, hook))
    u = UNSAFE.search(text)
    if u:
        return {"skip": f"needs network or a service ({u.group(0).strip()})"}
    tmp = tempfile.mkdtemp(prefix="brg-probe-")
    try:
        git_init(tmp)
        d = os.path.dirname(hook)
        shutil.copytree(os.path.join(repo, d), os.path.join(tmp, d))
        mk = makefile(repo)
        if mk:
            copy(repo, tmp, mk)
        name = os.path.basename(hook)
        args = []
        if name == "commit-msg" or name == "prepare-commit-msg":
            msg = os.path.join(tmp, ".git", "COMMIT_EDITMSG")
            open(msg, "w").close()
            args = [msg]
        elif name == "pre-push":
            args = ["origin", "file:///dev/null"]
        rc, out = run(["bash", hook] + args, tmp, timeout)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if rc is None:
        return {"skip": f"timed out after {timeout}s on empty input"}
    code = [
        l.strip()
        for l in text.split("\n")
        if l.strip() and not l.strip().startswith("#")
    ]
    static = []
    if re.search(r"\bgit\s+add\b(?![^\n]*(-p\b|--patch))", text):
        static.append("re-stages files with git add, so unstaged hunks are committed")
    if (
        code
        and re.match(r"^exit\s+0\b", code[-1])
        and not re.search(r"exit\s+[1-9]|set\s+-[a-z]*e", text)
    ):
        static.append("always exits 0, so it cannot block")
    return {
        "rc": rc,
        "count": count_line(out),
        "kept": [os.path.dirname(hook) + "/"],
        "static": static,
    }


INSTALLERS = re.compile(
    r"core\.hooksPath|\bhusky\b|lefthook\s+install|pre-commit\s+install|simple-git-hooks"
)


def hook_install(repo, hook_dir):
    """Who points git at hook_dir: this clone's config, a script, or only a doc."""
    r = subprocess.run(
        ["git", "-C", repo, "config", "--get", "core.hooksPath"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    here = r.stdout.strip() if r.returncode == 0 else ""
    setters, docs = [], []
    for rel in tracked(repo):
        base = os.path.basename(rel)
        doc = rel.lower().endswith((".md", ".rst", ".txt", ".adoc"))
        code = (
            base in ("Makefile", "makefile", "GNUmakefile", "package.json", "justfile")
            or rel.endswith((".mk", ".sh", ".bash", ".py", ".mjs", ".cjs", ".js"))
            or rel.startswith((".devcontainer/", "bin/", "scripts/"))
        )
        if not (doc or code) or rel.startswith(hook_dir + "/"):
            continue
        if INSTALLERS.search(read(os.path.join(repo, rel))):
            (docs if doc else setters).append(rel)
    return here, setters, docs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--only", default=None)
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument(
        "--empty-only",
        action="store_true",
        help="skip the run on a copy of the repository as it is",
    )
    a = ap.parse_args()
    repo = os.path.abspath(a.repo)

    gates = {}  # name -> {"kind", "sources"}
    mk = makefile(repo)
    n_make = n_ci = n_hooks = 0
    check = make_gates(repo, mk) if mk else []
    for t in check:
        gates.setdefault(t, {"kind": "make", "sources": []})["sources"].append(
            "make check"
        )
        n_make += 1
    jobs = ci_jobs(repo)
    files = ci_files(repo)
    for j in jobs:
        for t in j["targets"]:
            gates.setdefault(t, {"kind": "make", "sources": []})["sources"].append(
                f"CI {j['file']} job {j['name']}"
            )
            n_ci += 1
    hooks, runners = hook_gates(repo)
    for h, src in hooks:
        gates[h] = {"kind": "hook", "sources": [src]}
        n_hooks += 1
    for r in runners:
        gates[r] = {"kind": "runner", "sources": [r]}
        n_hooks += 1
    if a.only:
        gates = {
            k: v
            for k, v in gates.items()
            if a.only in k or any(a.only in s for s in v["sources"])
        }
        jobs = [j for j in jobs if a.only in j["name"] or a.only in j["targets"]]
    if not gates:
        print(
            f"gate-probe: 0 gates found in {repo} (no check target, no CI make call, no hooks), nothing checked",
            file=sys.stderr,
        )
        return 1
    if any(g["kind"] == "make" for g in gates.values()) and not mk:
        for k, g in gates.items():
            if g["kind"] == "make":
                g["kind"] = "nomake"

    real_dir, n_real = None, 0
    if not a.empty_only and any(g["kind"] == "make" for g in gates.values()):
        real_dir, n_real = build_real(repo)
    probed = fails = counts = skipped = passes_real = 0
    problems, lines = [], []
    try:
        for name, g in gates.items():
            src = "; ".join(dict.fromkeys(g["sources"]))
            if g["kind"] == "runner":
                r = {
                    "skip": "a hook runner config; probe the commands it runs through make"
                }
            elif g["kind"] == "nomake":
                r = {"skip": "CI calls make but the repository has no Makefile"}
            elif g["kind"] == "hook":
                r = probe_hook(repo, name, a.timeout)
            else:
                r = probe_make(repo, mk, name, a.timeout, real_dir)
            if "skip" in r:
                skipped += 1
                lines.append(f"not probed: {name} ({src}): {r['skip']}")
                continue
            probed += 1
            failed = r["rc"] != 0
            fails += failed
            e_part = (
                f"empty input {'fails (exit ' + str(r['rc']) + ')' if failed else 'PASSES (exit 0)'}, "
                f"count {repr(r['count']) if r['count'] else 'none'}"
            )
            r_part = ""
            count = r["count"]
            if "real_rc" in r:
                rrc = r["real_rc"]
                if rrc is None:
                    r_part = f"; repository timed out after {a.timeout}s"
                elif rrc == 0:
                    passes_real += 1
                    count = r["real_count"]
                    r_part = f"; repository passes (exit 0), count {repr(count) if count else 'none'}"
                else:
                    r_part = f"; repository FAILS (exit {rrc}): {r['real_last']!r}"
                    problems.append(f"{name}: fails on the repository as it is (exit {rrc})")
                if r.get("real_zero"):
                    problems.append(f"{name}: reports zero items examined on the repository")
                if r.get("real_same"):
                    problems.append(
                        f"{name}: same output on the repository as on empty input; nothing shows it examined anything"
                    )
            counts += bool(count)
            lines.append(f"gate: {name} ({src}): {e_part}{r_part}; kept {', '.join(r['kept'])}")
            if not failed:
                problems.append(f"{name}: passes on empty input")
            if not count:
                problems.append(f"{name}: prints no count")
            for e in r.get("escapes", []):
                problems.append(f"{name}: exit-code escape `{e}`")
            for st in r.get("static", []):
                problems.append(f"{name}: {st}")
    finally:
        if real_dir:
            shutil.rmtree(real_dir, ignore_errors=True)

    # CI: which jobs cannot block, which never run, which check gates no blocking job runs.
    all_files = tracked(repo) if jobs else []
    blocking_targets, nonblocking = set(), 0
    for j in jobs:
        why = list(j["nonblocking"])
        if j["changes"]:
            hits = sum(
                1 for f in all_files if any(glob_re(c).match(f) for c in j["changes"])
            )
            why.append(f"runs only when {', '.join(j['changes'])} changes ({hits} files match)")
            if hits == 0:
                problems.append(
                    f"CI job {j['name']}: its changes rule matches 0 files in the repository, so it never runs"
                )
        for n in j["nonblocking"]:
            problems.append(f"CI job {j['name']}: {n}, so it cannot block a merge")
        for e in j["escapes"]:
            problems.append(f"CI job {j['name']}: exit-code escape `{e}`")
        if not j["nonblocking"] and not j["changes"]:
            ts = set(j["targets"])
            if "check" in ts:
                ts |= set(check)
            blocking_targets |= ts
        else:
            nonblocking += 1
        lines.append(
            f"ci-job: {j['name']} ({j['file']}): make {' '.join(j['targets']) or '(none)'}; "
            + ("; ".join(why) if why else "blocking on every pipeline")
        )
    if files:
        for t in check:
            if (not a.only or t in gates) and t not in blocking_targets:
                problems.append(f"{t}: in make check but no CI job runs it on every merge request as a blocking step")

    # Hooks: who installs them.
    for d in sorted({os.path.dirname(h) for h, _ in hooks if h in gates}):
        here, setters, docs = hook_install(repo, d)
        lines.append(
            f"hooks: {d}: core.hooksPath in this clone {here or 'unset'}; "
            f"installed by {', '.join(setters) or 'nothing in the repository'}; "
            f"documented in {', '.join(docs) or 'no document'}"
        )
        if not setters and here.rstrip("/") != d:
            problems.append(
                f"{d}: nothing in the repository installs these hooks"
                + (f" (only a manual step in {', '.join(docs)})" if docs else "")
                + ", so they run for nobody who has not set core.hooksPath by hand"
            )

    for line in lines:
        print(line)
    for p in problems:
        print(f"problem: {p}")
    need = len({p.split(":")[0] for p in problems})
    print(
        f"gate-probe: {len(gates)} gates found (make {n_make}, CI {n_ci} in {len(files)} files, hooks {n_hooks}), "
        f"{probed} probed, {fails} fail on empty input, "
        + (f"{passes_real} pass on the repository ({n_real} files copied), " if real_dir else "")
        + f"{counts} print a count, {skipped} not probed, "
        f"CI jobs {len(jobs)} ({nonblocking} not blocking on every merge request), {need} need work"
    )
    if probed == 0:
        print("gate-probe: 0 gates probed, nothing checked", file=sys.stderr)
        return 1
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
