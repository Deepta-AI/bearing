#!/usr/bin/env python3
"""skill-evals: run a Bearing skill's evals against no skill, graded blind,
and record the measured result for the maintainers.

The cases live in evals/<name>/evals.json, away from the skill so a run that
follows the skill cannot read its grading (skill-creator's case schema;
`files[0]` is a fixture repository under evals/<name>/files/, whose optional
.eval-branch names the branch to check out). The workspace is
.scratch/skill-evals/<name>/iteration-<N>/, one folder per case, one per
arm inside it, in the layout skill-creator's aggregate_benchmark.py reads.

Arms:
  with_skill            reads the kit's SKILL.md from this checkout and follows it
  without_skill         no skill at all
  with_the_alternative  optional, maintainers only: runs when the untracked
                        .scratch/private/comparisons.json exists and names an
                        installed skill for this one (never another Bearing
                        skill). Nothing committed names such a skill.
Folders are named arm-1..arm-N until grading is done, so the grader does not
know which arm produced what; `unblind` renames them. The benchmark's delta is
the first two configurations in sorted order.

Results go to .scratch/private/comparisons.json (git ignores .scratch/), never
to a tracked file: the measured numbers are an internal audit, not something
the docs or the sites publish.

  skill-evals.py prepare <skill> [--iteration N]   workspace, fixtures, prompts
  skill-evals.py reset <run dir>...               rebuild interrupted runs from the fixture
  skill-evals.py timing <run dir> <tokens> <ms>    record a finished run
  skill-evals.py grade-prompt <skill> [--iteration N]
                                                   one blind grader brief per case
  skill-evals.py unblind <skill> [--iteration N]   arm-k -> arm name
  skill-evals.py measure <skill> [--iteration N] --model <id>
                                                   benchmark + the private results file
  skill-evals.py status                            where every skill stands

Each command prints the count of what it handled and exits 1 on zero.
"""

import argparse
import datetime
import json
import os
import random
import re
import shutil
import site
import subprocess
import sys

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(KIT, "bin"))
import kit_paths  # noqa: E402

WS = os.path.join(KIT, ".scratch", "skill-evals")
# Internal and untracked: .scratch/ is in .gitignore.
COMPARISONS = os.path.join(KIT, ".scratch", "private", "comparisons.json")
ARMS = ["with_skill", "with_the_alternative", "without_skill"]


def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(1)


def meta_path(case_dir):
    """Where a case's assertions wait until grading: .scratch/skill-evals/_meta/<skill>/<iteration>/<case>.json."""
    rel = os.path.relpath(os.path.abspath(case_dir), WS)
    p = os.path.join(WS, "_meta", rel + ".json")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def dump(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
        f.write("\n")


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:48]


def bearing_skills():
    """The Bearing skills: every directory holding a SKILL.md under a Bearing
    plugin's skills/ (bearing, bearing-backend, bearing-apps)."""
    return [d.name for d in kit_paths.skill_dirs()]


def private():
    """The maintainers' untracked results file, or {} when there is none."""
    return load(COMPARISONS) if os.path.isfile(COMPARISONS) else {}


def alternative(skill):
    """The invoke name for the optional third arm, or None when there is none:
    no private file, no entry, not installed, or another Bearing skill."""
    c = private().get(skill, {})
    b = c.get("best_alternative") or {}
    inv = (b.get("invoke") or "").strip()
    if not inv or not b.get("installed") or inv.lstrip("/") in bearing_skills():
        return None
    if user_only(inv):
        # A skill marked disable-model-invocation refuses the Skill tool, so an
        # unattended arm can only stop; measure against no skill instead.
        return None
    return inv


def skill_file(inv):
    """The SKILL.md of an installed copy of the skill, preferring ~/.claude/skills, or None."""
    name = inv.lstrip("/").split(":")[-1]
    for root in (
        os.path.expanduser("~/.claude/skills"),
        os.path.expanduser("~/.claude/plugins"),
    ):
        for dp, dns, fns in os.walk(root):
            dns[:] = [d for d in dns if not d.startswith(".") and d != "node_modules"]
            if os.path.basename(dp) == name and "SKILL.md" in fns:
                return os.path.join(dp, "SKILL.md")
    return None


def user_only(inv):
    """True when every installed copy of the skill is user-invocable only."""
    name = inv.lstrip("/").split(":")[-1]
    found = []
    for root in (
        os.path.expanduser("~/.claude/plugins"),
        os.path.expanduser("~/.claude/skills"),
    ):
        for dp, dns, fns in os.walk(root):
            dns[:] = [d for d in dns if not d.startswith(".") and d != "node_modules"]
            if os.path.basename(dp) == name and "SKILL.md" in fns:
                with open(
                    os.path.join(dp, "SKILL.md"), encoding="utf-8", errors="replace"
                ) as f:
                    head = f.read(4000).split("\n---", 1)[0]
                found.append(
                    re.search(r"^disable-model-invocation:\s*true", head, re.M)
                    is not None
                )
    return bool(found) and all(found)


def git(repo, *args):
    subprocess.run(
        [
            "git",
            "-C",
            repo,
            "-c",
            "user.name=eval",
            "-c",
            "user.email=eval@localhost",
            *args,
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def run_home(run_dir):
    """The run's own HOME, with a git identity that is not the operator's."""
    home = os.path.join(run_dir, "scratch", "home")
    os.makedirs(home, exist_ok=True)
    with open(os.path.join(home, ".gitconfig"), "w", encoding="utf-8") as f:
        f.write("[user]\n\tname = Eval Run\n\temail = eval-run@localhost.invalid\n")
    return home


def run_env(run_dir):
    # A run inherits the operator's shell: without these, its commits carry the
    # operator's name and email from ~/.gitconfig, a skill's tooling writes
    # session files into the real home, and pnpm fills the shared store from the
    # network even with offline set. The new HOME would also hide the pub and npm caches
    # that let a run build offline, so those point back at the real ones (Go keeps its
    # per-run caches, set in executor_prompt).
    home = run_home(run_dir)
    real = os.path.expanduser("~")
    return f"""Run every shell command with HOME={home} (it holds this run's git identity), GIT_CONFIG_NOSYSTEM=1,
PYTHONUSERBASE={site.getuserbase()} (so installed Python tools still import), npm_config_offline=true and
npm_config_registry=http://127.0.0.1:9/ (unreachable on purpose), pnpm_config_offline=true and
pnpm_config_registry=http://127.0.0.1:9/ (pnpm 11 ignores the npm_config_ names), COREPACK_ENABLE_NETWORK=0
(corepack otherwise downloads package managers), and keep the machine's offline caches visible:
GOPROXY=off, PUB_CACHE={real}/.pub-cache, npm_config_cache={real}/.npm
(read them, never clear them), npm_config_logs_dir={home}/npm-logs (npm writes logs beside its cache otherwise), RUFF_CACHE_DIR={home}/ruff-cache. Never set a git author or committer yourself (no
`-c user.name`, `-c user.email`, `--author` or GIT_AUTHOR_* values), and never write under the real home directory or /tmp
(keep every scratch file inside this run folder). Other runs work on this machine at the same time: a server you start
listens on a port you picked free (bind port 0, or check the port is unused and retry another), you talk only to servers
you started, and you stop every process you started before you reply. Do not use the Playwright or browser MCP tools
(one browser is shared by every run and writes outside this folder); to look at a page, launch your own headless browser
from a script with its output inside this run folder."""


def executor_prompt(skill, arm, alt, case, repo, run_dir):
    common = f"""You are one run of a skill evaluation. A user typed the request below in the repository at
  {repo}
Work only inside that repository (read, edit and run commands there). Nobody is available to answer
questions: where you would ask the user something, pick the option you would recommend, and note
the question and your choice. Where a procedure says to stop and wait for the user's agreement or
answer before going on, carry on with your recommended option as a working assumption so the whole
task is finished in this run, and record the question and the assumption. The user has not decided
anything: any decision record, ADR or document you write shows such a choice as Proposed (awaiting
the user), never Accepted or approved, and names no person as having decided or authored it.
Never push, deploy or publish anything; nothing outside the repository may change. Do not install
packages from the network. If a procedure starts helper agents, run each in the foreground and wait
for its result (never in the background): a background helper's completion notice does not reach
you, and a run that waits for one never finishes. Keep your scratch files under {run_dir}/scratch,
never a shared temp folder, and for Go set GOMODCACHE={run_dir}/cache/gomod and
GOCACHE={run_dir}/cache/gobuild (with GOTOOLCHAIN=local), so no other run's cache is read or changed.
If the repository has an Android or Gradle build, do not run ./gradlew or Gradle at all (the wrapper downloads
its distribution before it reads --offline and none is installed here) and say that build was not run;
otherwise do not mention Gradle.
Run every command with BEARING_ENV=/dev/null and no BEARING_TRACKER or BEARING_GIT_HOST set, so no real
tracker or host configuration is read. {run_env(run_dir)}
Never run a command that changes or contacts a cluster or cloud (kubectl apply/delete/rollout or any kubectl call that
reaches a server, helm install/upgrade, terraform apply, a make deploy target, a cloud CLI): to test a guard or script that
would call one, put a fake binary of that name first on PATH inside this run's scratch folder. Offline rendering and
validation are fine and expected (kubectl kustomize, helm template, terraform validate, the repository's make check).
Never stop a process by name or pattern (pkill -f, killall): other runs share this machine; stop only
process ids you started. Never connect to a database, container or service you did not start in this run: other projects'
containers run on this machine. If you start a container, pick a port you first confirmed is free,
check that your container is the one listening before using it, and remove it when you finish.

The request:
---
{case["prompt"]}
---
"""
    if arm == "with_skill":
        sdir = kit_paths.skill_dir(skill)
        proot = sdir.parent.parent
        how = f"""How to work: read {sdir}/SKILL.md and follow it as your procedure, reading the
files it points to. Wherever it says ${{CLAUDE_PLUGIN_ROOT}}, use {proot}. Do not use the Skill tool
for any Bearing skill (bearing:<name>, bearing-backend:<name> or bearing-apps:<name>; the installed
copy is an older version); read the file under {KIT}/plugins instead. Do not load any
other skill. Never open anything under {KIT}/evals/: it holds the grading for this
run, and reading it spoils the run."""
    elif arm == "with_the_alternative":
        sf = skill_file(alt)
        # A subagent's Skill tool may not list every user skill; the file is
        # the same procedure, so a refusal must not end the run.
        fallback = (
            f" If the Skill tool does not know it, read {sf} and the files it points to\n"
            "instead and follow that; either way this arm's procedure is that skill."
            if sf
            else ""
        )
        how = f"""How to work: load the skill `{alt}` with the Skill tool and follow it as your procedure.{fallback} Do not
load or read any Bearing skill (bearing:, bearing-backend: or bearing-apps:<name>), and do not read
anything under {KIT}."""
    else:
        how = f"""How to work: use your own judgement. Do not use the Skill tool, and do not read any SKILL.md
file or anything under {KIT} or ~/.claude."""
    return f"""{common}
{how}

When you are done, write {run_dir}/transcript.md with: the steps you took in order, each command you
ran with the part of its output that mattered, every question you would have asked and what you
chose, and the final message you would give the user. Describe what you did; do not name which
skill or instructions you followed. Then reply with one line: done, or the reason you stopped.
"""


def prepare(a):
    ed_src = os.path.join(KIT, "evals", a.skill)
    ev = os.path.join(ed_src, "evals.json")
    if not os.path.isfile(ev):
        die(
            f"skill-evals: {a.skill} has no evals/{a.skill}/evals.json, nothing prepared"
        )
    data = load(ev)
    alt = alternative(a.skill)
    arms = ARMS if alt else [x for x in ARMS if x != "with_the_alternative"]
    it = os.path.join(WS, a.skill, f"iteration-{a.iteration}")
    if os.path.exists(it):
        die(f"skill-evals: {it} exists; use --iteration {a.iteration + 1}")
    runs = []
    for case in data["evals"]:
        name = case.get("name") or f"case-{case['id']}"
        ed = os.path.join(it, f"eval-{case['id']}-{slug(name)}")
        os.makedirs(ed)
        # The assertions stay out of the run-visible tree until grade-prompt, so a
        # run that looks around its own folder cannot read its grading.
        dump(
            meta_path(ed),
            {
                "eval_id": case["id"],
                "eval_name": name,
                "prompt": case["prompt"],
                "assertions": case["expectations"],
            },
        )
        order = list(arms)
        random.Random(f"{a.skill}:{case['id']}:{a.iteration}").shuffle(order)
        mapping = {f"arm-{i + 1}": arm for i, arm in enumerate(order)}
        dump(os.path.join(ed, "arms.json"), mapping)
        fixture = os.path.join(ed_src, case["files"][0]) if case.get("files") else None
        for blind, arm in mapping.items():
            rd = os.path.join(ed, blind, "run-1")
            repo = os.path.join(rd, "outputs", "repo")
            build_repo(fixture, repo)
            with open(os.path.join(rd, "prompt.txt"), "w", encoding="utf-8") as f:
                f.write(executor_prompt(a.skill, arm, alt, case, repo, rd))
            runs.append(rd)
    print(
        f"skill-evals: {a.skill} iteration {a.iteration}: {len(data['evals'])} cases x {len(arms)} arms"
        f" ({', '.join(arms)}{'; alternative ' + alt if alt else '; no alternative arm'}) = {len(runs)} runs"
    )
    for r in runs:
        print(os.path.relpath(r, KIT))
    return 0 if runs else 1


def build_repo(fixture, repo):
    """Copy the fixture to repo and commit it as the tag `fixture`."""
    if fixture and os.path.isdir(fixture):
        shutil.copytree(fixture, repo, ignore=shutil.ignore_patterns("__pycache__", ".pytest_cache", ".ruff_cache", ".mypy_cache", "node_modules"))
    else:
        os.makedirs(repo)
    # A fixture keeps files a secret scanner or the guard would refuse (an
    # env file with planted fake keys) as `dot<name>.evalfile`; the run sees
    # them as `.<name>`.
    for d, _, names in os.walk(repo):
        for n in names:
            if n.endswith(".evalfile"):
                real = n[: -len(".evalfile")]
                if real.startswith("dot"):
                    real = "." + real[3:]
                os.rename(os.path.join(d, n), os.path.join(d, real))
    if os.path.isfile(os.path.join(repo, ".eval-setup.sh")):
        # The fixture builds its own history (branches, remote-tracking refs,
        # an uncommitted edit) and removes the script; the state it leaves is
        # the starting point the grader diffs against.
        # The script sets its own authors; the environment pins a neutral
        # identity for any commit that does not, so none carries the operator's.
        env = dict(
            os.environ,
            GIT_CONFIG_GLOBAL=os.devnull,
            GIT_CONFIG_NOSYSTEM="1",
            GIT_AUTHOR_NAME="eval",
            GIT_AUTHOR_EMAIL="eval@localhost",
            GIT_COMMITTER_NAME="eval",
            GIT_COMMITTER_EMAIL="eval@localhost",
        )
        subprocess.run(["bash", ".eval-setup.sh"], cwd=repo, check=True, env=env)
        git(repo, "tag", "fixture")
        return
    branch = "main"
    bf = os.path.join(repo, ".eval-branch")
    if os.path.isfile(bf):
        branch = open(bf).read().strip() or "main"
        os.remove(bf)
    git(repo, "init", "-q", "-b", branch)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "--allow-empty", "-m", "fixture")
    git(repo, "tag", "fixture")


def reset(a):
    """Rebuild interrupted runs from their fixtures so they can run again."""
    n = 0
    for rd in a.run_dirs:
        rd = os.path.abspath(rd.rstrip("/"))
        rel = os.path.relpath(rd, WS).split(os.sep)
        if len(rel) != 5 or rel[4] != "run-1" or not rel[2].startswith("eval-"):
            die(f"skill-evals: {rd} is not a run directory under {WS}")
        skill, case_id = rel[0], int(rel[2].split("-")[1])
        case = next(
            c
            for c in load(os.path.join(KIT, "evals", skill, "evals.json"))["evals"]
            if c["id"] == case_id
        )
        fixture = (
            os.path.join(KIT, "evals", skill, case["files"][0])
            if case.get("files")
            else None
        )
        for name in ("transcript.md", "timing.json", "grading.json"):
            if os.path.exists(os.path.join(rd, name)):
                os.remove(os.path.join(rd, name))
        repo = os.path.join(rd, "outputs", "repo")
        if os.path.exists(repo):
            shutil.rmtree(repo)
        build_repo(fixture, repo)
        n += 1
        print(f"skill-evals: reset {os.path.relpath(rd, KIT)}")
    if n == 0:
        die("skill-evals: 0 runs reset")
    return 0


def timing(a):
    if not os.path.isdir(a.run_dir):
        die(f"skill-evals: {a.run_dir} is not a run directory")
    dump(
        os.path.join(a.run_dir, "timing.json"),
        {
            "total_tokens": int(a.tokens),
            "duration_ms": int(a.ms),
            "total_duration_seconds": round(int(a.ms) / 1000, 1),
        },
    )
    print(f"skill-evals: timing written for {a.run_dir}")
    return 0


def grade_prompt(a):
    it = os.path.join(WS, a.skill, f"iteration-{a.iteration}")
    sc = skill_creator()
    if not sc:
        die(
            "skill-evals: skill-creator not found; its agents/grader.md is the grading method"
        )
    n = waiting = 0
    for ed in sorted(os.listdir(it)) if os.path.isdir(it) else []:
        d = os.path.join(it, ed)
        if not os.path.isfile(os.path.join(d, "arms.json")):
            continue
        # Every run is finished (checked below), so the assertions can now sit
        # where the grader and aggregate_benchmark.py read them.
        if not os.path.isfile(os.path.join(d, "eval_metadata.json")):
            if not os.path.isfile(meta_path(d)):
                die(
                    f"skill-evals: {ed}: no eval_metadata.json in the case or {meta_path(d)}"
                )
        blinds = sorted(b for b in os.listdir(d) if b.startswith("arm-"))
        missing = [
            b
            for b in blinds
            if not os.path.isfile(os.path.join(d, b, "run-1", "transcript.md"))
        ]
        if missing:
            # A case still running is skipped, not fatal: a finished case sorted
            # after it must still get its brief.
            print(
                f"skill-evals: {ed}: skipped, no transcript.md yet in {', '.join(missing)}"
            )
            waiting += 1
            continue
        if not os.path.isfile(os.path.join(d, "eval_metadata.json")):
            shutil.copyfile(meta_path(d), os.path.join(d, "eval_metadata.json"))
        meta = load(os.path.join(d, "eval_metadata.json"))
        exp = "\n".join(f"{i + 1}. {e}" for i, e in enumerate(meta["assertions"]))
        arms = "\n".join(f"- {b}: {os.path.join(d, b, 'run-1')}" for b in blinds)
        text = f"""You grade one case of a skill evaluation, blind. Read {sc}/agents/grader.md and follow its
method (steps 1 to 7). Several runs got the same request; grade each run on its own, to the same
standard. Do not try to work out how a run was produced: do not read arms.json, any run's
prompt.txt (it names the procedure the run followed), or anything outside the run folders
listed below and the files they contain.

The request each run received:
---
{meta["prompt"]}
---

Expectations (grade every one for every run, text copied exactly into the "text" field):
{exp}

Runs (each holds transcript.md and outputs/repo, a git repository whose starting state is the tag
`fixture`; `git -C <repo> diff fixture` and `git -C <repo> status --porcelain` show what the run
changed, including files it created):
{arms}

You may run read-only commands and the repository's own checks (for example `make check`, `go test ./...`,
`python3 <script>`) inside a run's repository; do not edit, add or delete any file there. Run every command
with HOME set to a folder in your scratchpad, npm_config_offline=true, npm_config_registry=http://127.0.0.1:9/, pnpm_config_offline=true, pnpm_config_registry=http://127.0.0.1:9/, COREPACK_ENABLE_NETWORK=0,
PYTHONUSERBASE={site.getuserbase()} and PUB_CACHE={os.path.expanduser("~")}/.pub-cache (read only, so installed tools resolve),
never run a deploy command for real, and never write under the real home directory or /tmp. An
expectation about a check passing is graded by running it yourself, never by the transcript's word.
The burden of proof is on the expectation: no evidence is a fail. A file with the right name and the
wrong content is a fail.

Write <run folder>/grading.json for every run, in grader.md's format with fields text, passed and
evidence, and the summary block (passed, failed, total, pass_rate). Add "eval_feedback" with any
expectation that was not discriminating or any outcome no expectation covers. Reply with one line per
run: the run folder name and passed/total.
"""
        with open(os.path.join(d, "grader_prompt.txt"), "w", encoding="utf-8") as f:
            f.write(text)
        n += 1
    if n == 0:
        die(
            f"skill-evals: 0 grader briefs written under {it} ({waiting} cases still running)"
        )
    print(f"skill-evals: {n} grader briefs written, {waiting} cases still running")
    return 0


def unblind(a):
    it = os.path.join(WS, a.skill, f"iteration-{a.iteration}")
    n = 0
    for ed in sorted(os.listdir(it)) if os.path.isdir(it) else []:
        mp = os.path.join(it, ed, "arms.json")
        if not os.path.isfile(mp):
            continue
        for blind, arm in load(mp).items():
            src = os.path.join(it, ed, blind)
            if os.path.isdir(src):
                if not os.path.isfile(os.path.join(src, "run-1", "grading.json")):
                    die(
                        f"skill-evals: {src} has no grading.json; grade before unblinding"
                    )
                os.rename(src, os.path.join(it, ed, arm))
                n += 1
    if n == 0:
        die(f"skill-evals: 0 arm folders unblinded under {it}")
    print(f"skill-evals: {n} arm folders unblinded")
    return 0


def skill_creator():
    roots = [os.path.expanduser(p) for p in ("~/.claude", "~/.config/Claude")]
    for root in roots:
        for dp, dns, _ in os.walk(root):
            if dp.endswith(os.path.join("skills", "skill-creator")) and os.path.isfile(
                os.path.join(dp, "scripts", "aggregate_benchmark.py")
            ):
                return dp
            dns[:] = [d for d in dns if not d.startswith(".") and d != "node_modules"]
    return None


def measure(a):
    it = os.path.join(WS, a.skill, f"iteration-{a.iteration}")
    sc = skill_creator()
    if not sc:
        die("skill-evals: skill-creator's aggregate_benchmark.py not found")
    subprocess.run(
        [
            sys.executable,
            "-m",
            "scripts.aggregate_benchmark",
            it,
            "--skill-name",
            a.skill,
        ],
        cwd=sc,
        check=True,
        stdout=subprocess.DEVNULL,
    )
    b = load(os.path.join(it, "benchmark.json"))
    rs = b.get("run_summary", {})
    arms = {k: v for k, v in rs.items() if k in ARMS}
    if "with_skill" not in arms or len(arms) < 2:
        die(
            f"skill-evals: benchmark for {a.skill} has {len(arms)} graded arms; need with_skill and one more"
        )
    cases = len([d for d in os.listdir(it) if d.startswith("eval-")])

    # Tokens and executor time come from each run's timing.json (written from
    # the task notification); graders copy timing without tokens, so the
    # benchmark's own token figure can be zero.
    def run_timing(arm):
        ts = []
        for ed in os.listdir(it):
            tf = os.path.join(it, ed, arm, "run-1", "timing.json")
            if os.path.isfile(tf):
                ts.append(load(tf))
        if not ts:
            return 0, 0.0
        return (
            int(sum(t["total_tokens"] for t in ts) / len(ts)),
            round(sum(t["total_duration_seconds"] for t in ts) / len(ts), 1),
        )

    out = {}
    for k, v in arms.items():
        tok, sec = run_timing(k)
        out[k] = {
            "pass_rate": round(v["pass_rate"]["mean"], 3),
            "tokens": tok,
            "seconds": sec,
        }
    art = out["with_skill"]["pass_rate"]
    rivals = {k: v["pass_rate"] for k, v in out.items() if k != "with_skill"}
    best = max(rivals, key=rivals.get)
    # Rounded so 0.96 - 0.86 counts as the 10 points it is, not 0.0999...
    margin = round(art - rivals[best], 4)
    result = (
        "bearing ahead"
        if margin >= 0.10
        else "rival ahead"
        if margin <= -0.10
        else "within 10 points"
    )
    c = private()
    c.setdefault(a.skill, {})["measured"] = {
        "date": datetime.date.today().isoformat(),
        "model": a.model,
        "iteration": a.iteration,
        "cases": cases,
        "runs_per_arm": 1,
        "arms": out,
        "result": result,
        "closest": best,
        "margin": round(margin, 3),
    }
    os.makedirs(os.path.dirname(COMPARISONS), exist_ok=True)
    dump(COMPARISONS, c)
    print(
        f"skill-evals: {a.skill} measured on {cases} cases: "
        + ", ".join(f"{k} {v['pass_rate']:.2f}" for k, v in out.items())
        + f"; {result} ({best}, {margin * 100:+.1f} points)"
    )
    return 0


def status(a):
    c = private()
    skills = bearing_skills()
    if not skills:
        die("skill-evals: 0 skills found")
    with_evals = [
        s for s in skills if os.path.isfile(os.path.join(KIT, "evals", s, "evals.json"))
    ]
    measured = [s for s in skills if c.get(s, {}).get("measured")]
    print(
        f"skill-evals: {len(skills)} skills, {len(with_evals)} with evals, {len(measured)} measured"
    )
    for s in measured:
        m = c[s]["measured"]
        print(
            f"  {s}: {m['result']} ({m['closest']}, {m['margin'] * 100:+.1f} points) on {m['cases']} cases, {m['date']}"
        )
    todo = [s for s in with_evals if s not in measured]
    if todo:
        print("  evals written, not measured: " + ", ".join(todo))
    return 0


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sp = ap.add_subparsers(dest="cmd", required=True)
    for name in ("prepare", "grade-prompt", "unblind", "measure"):
        p = sp.add_parser(name)
        p.add_argument("skill")
        p.add_argument("--iteration", type=int, default=1)
        if name == "measure":
            p.add_argument("--model", required=True)
    p = sp.add_parser("reset")
    p.add_argument("run_dirs", nargs="+")
    p = sp.add_parser("timing")
    p.add_argument("run_dir")
    p.add_argument("tokens")
    p.add_argument("ms")
    sp.add_parser("status")
    a = ap.parse_args()
    return {
        "prepare": prepare,
        "reset": reset,
        "timing": timing,
        "grade-prompt": grade_prompt,
        "unblind": unblind,
        "measure": measure,
        "status": status,
    }[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
