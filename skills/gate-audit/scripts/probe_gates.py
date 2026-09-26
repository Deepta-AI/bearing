#!/usr/bin/env python3
"""probe_gates: run every gate once on empty input, in a throwaway copy of
the repository, and report whether it fails there and whether it prints a
count. The repository itself is never written.

Gates found:
  - make: the prerequisites of `check` in the root Makefile and the words
    of its GATES variable (`check` itself when it has no prerequisites).
  - CI: every `make <targets>` at a command position in .gitlab-ci.yml, .github/workflows/*.y*ml,
    .circleci/config.yml, bitbucket-pipelines.yml or Jenkinsfile, named by
    the job it sits under. A target already found is probed once.
  - hooks: the git hooks (pre-commit, commit-msg, pre-push,
    prepare-commit-msg, pre-merge-commit, pre-rebase) in .githooks/ or
    .husky/. lefthook.yml and .pre-commit-config.yaml are listed as not
    probed (a runner config; probe the commands it runs through make).

The empty copy, per gate, in a fresh temporary directory:
  - make gates: the Makefile, its includes and *.mk files, root tool
    configs (package.json, go.mod, pyproject.toml, tsconfig*.json, lint
    configs), and each script the dry run (`make -n <target>`) invokes
    (a path right after bash, sh, python3, node, source, or an
    executable at a command's start), with the sibling files that script
    names. A directory the dry run names is created empty. Everything
    else, the gate's input, is left out. node_modules, .venv and vendor
    are symlinked so tools resolve. Then `git init` with the kept files in
    .git/info/exclude (so git-based gates see an empty repository) and
    `make -s <target>`. The dry run itself runs in the repository, so a
    recipe line make executes under -n ($(MAKE), a + prefix, $(shell))
    does run there.
  - hooks: the hook directory and the Makefile in an empty `git init`
    repository with nothing staged; commit-msg gets an empty message file,
    pre-push an empty ref list.
  - Each run has --timeout seconds (default 120), network-offline
    variables for Go, npm, pip and uv, and is killed with its process
    group on timeout.

Not probed, with the reason: a dry run or hook that names docker, a
cloud or cluster CLI, curl, wget, ssh, a database client, gh or glab, a
package install, git push/fetch/pull/clone, npx, DATABASE_URL, deploy or
publish; a CI target the root Makefile lacks; a dry run that fails; a
timeout.

A count is a line of output holding a number followed by a word ("0
files", "12 packages") or the words "nothing checked".

Usage: probe_gates.py [--repo .] [--only NAME] [--timeout S]
Prints one line per gate, one "problem:" line per gate that passes on
empty input or prints no count, a "not probed:" line per gate skipped, and
the counts; exits 1 on any problem, or when zero gates were found or zero
were probed.
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
    for n in ("GNUmakefile", "makefile", "Makefile"):
        if os.path.isfile(os.path.join(repo, n)):
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


def ci_gates(repo):
    """(target, source) for each make call at a command position in a CI file."""
    out = []
    files = [f for f in CI_FILES if os.path.isfile(os.path.join(repo, f))]
    files += sorted(
        os.path.relpath(p, repo)
        for p in glob.glob(os.path.join(repo, ".github/workflows/*.y*ml"))
    )
    for f in files:
        job, in_jobs = "?", False
        github = f.startswith(".github/")
        for line in read(os.path.join(repo, f)).split("\n"):
            if line.lstrip().startswith("#"):
                continue
            if github:
                if re.match(r"^jobs:\s*$", line):
                    in_jobs = True
                j = re.match(r"^  ([A-Za-z0-9_.-]+):\s*$", line) if in_jobs else None
            else:
                j = re.match(r"^([^\s#][^#]*?):\s*$", line)
            if j:
                job = j.group(1)
            for m in re.finditer(
                r"(?:^\s*(?:-\s+)?(?:run:\s*)?|&&\s*|;\s*|\|\|\s*)make((?:\s+[A-Za-z0-9_$-][^\s;&|]*)+)",
                line,
            ):
                for t in m.group(1).split():
                    if not re.match(r"^[A-Za-z0-9_][A-Za-z0-9_.-]*$", t):
                        continue
                    out.append((t, f"CI {f} job {job}"))
    return out, files


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


def probe_make(repo, mk, target, timeout):
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
    return {"rc": rc, "count": count_line(out), "kept": kept}


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
    return {"rc": rc, "count": count_line(out), "kept": [os.path.dirname(hook) + "/"]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--only", default=None)
    ap.add_argument("--timeout", type=int, default=120)
    a = ap.parse_args()
    repo = os.path.abspath(a.repo)

    gates = {}  # name -> {"kind", "sources"}
    mk = makefile(repo)
    n_make = n_ci = n_hooks = 0
    if mk:
        for t in make_gates(repo, mk):
            gates.setdefault(t, {"kind": "make", "sources": []})["sources"].append(
                "make check"
            )
            n_make += 1
    ci, ci_files = ci_gates(repo)
    for t, src in ci:
        gates.setdefault(t, {"kind": "make", "sources": []})["sources"].append(src)
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

    probed = fails = counts = skipped = 0
    problems, lines = [], []
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
            r = probe_make(repo, mk, name, a.timeout)
        if "skip" in r:
            skipped += 1
            lines.append(f"not probed: {name} ({src}): {r['skip']}")
            continue
        probed += 1
        failed = r["rc"] != 0
        fails += failed
        counts += bool(r["count"])
        lines.append(
            f"gate: {name} ({src}): empty input {'fails (exit ' + str(r['rc']) + ')' if failed else 'PASSES (exit 0)'}, "
            f"count {'printed: ' + repr(r['count']) if r['count'] else 'none'}; kept {', '.join(r['kept'])}"
        )
        if not failed:
            problems.append(f"{name}: passes on empty input")
        if not r["count"]:
            problems.append(f"{name}: prints no count")
    for line in lines:
        print(line)
    for p in problems:
        print(f"problem: {p}")
    need = len({p.split(":")[0] for p in problems})
    print(
        f"gate-probe: {len(gates)} gates found (make {n_make}, CI {n_ci} in {len(ci_files)} files, hooks {n_hooks}), "
        f"{probed} probed, {fails} fail on empty input, {counts} print a count, {skipped} not probed, {need} need work"
    )
    if probed == 0:
        print("gate-probe: 0 gates probed, nothing checked", file=sys.stderr)
        return 1
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
