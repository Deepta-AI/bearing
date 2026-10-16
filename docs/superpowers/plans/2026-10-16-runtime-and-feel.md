# Runtime and Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Bearing fast and self-driving inside a session (scoped Stop gate, cheaper review agents, short skills, automatic save and resume, update prompt, opt-in local learning, one question contract) without removing any gate.

**Architecture:** Hook adapters stay thin. Today's `brg-guard` (1,796 lines) keeps its subcommands; new behaviour goes into four focused scripts beside it: `brg-session` (timeline, checkpoint, next step, resume block), `brg-config` (project and user answers), `brg-update-check`, `brg-learn`. `brg-guard session` calls them. Stack templates gain one `check-changed` target each. Skills shrink by moving detail into `references/`.

**Tech Stack:** bash 3.2 compatible shell (macOS CI), GNU and BSD portable (`make lint-portable` rejects `sed -i`, `perl`, `grep -P`, `readlink -f`, `date -d`), jq in hooks, python3 for generators, Make. Tests use `tests/lib/assert.sh`.

**Spec:** `docs/superpowers/specs/2026-10-16-runtime-and-feel-design.md`

## Global Constraints

- No em dashes in any shipped file (`make lint-prose`).
- No company or client names, no private tracker ids (`make lint-neutral`).
- Every new gate or lint fails on empty input and prints the count it checked.
- Every new hook step exits 0 on its own failure and logs `<gate> not-run <reason>` via `gate_log`; only the existing Stop gate may exit 2.
- Hook timeouts: 5 s or less for new hooks; Stop stays 15 s.
- State writes are atomic: write `<file>.tmp`, then `mv`.
- User config dir: `${XDG_CONFIG_HOME:-$HOME/.config}/bearing/`; user settings live in `bearing.env` there.
- Nothing leaves the machine except `git ls-remote` against the marketplace URL. Bearing never runs `git push`, `gh issue create` or a tag.
- Commits: Conventional Commits, no attribution trailer.
- Skill references directory is `references/` (the existing convention in `bearing-apps`), not the `reference/` the spec wrote; the shared console contract lives at `plugins/bearing/references/console.md`.
- After touching a skill, the stage map or flows: `make docs` and commit what it regenerates.
- The repository gate: `make check` ends with `check: passed`.

## Review Focus

1. A repository whose Makefile has no `check-changed` (every repo scaffolded before 0.8.0): the Stop gate must behave exactly as in 0.7.0. Pinned in Task 2.
2. A branch name with no task id (`main`, `feat/RuntimeAndFeel`): timeline, checkpoint and resume must still work and print `task=none`, never an empty `Resume :` line. Pinned in Tasks 12 and 14.
3. No network or a slow remote at session start: the session output must not wait more than the 3 s budget and must print nothing about updates. Pinned in Task 17.
4. Learning off or never answered: no file is written under the config dir by the learning code. Pinned in Task 18.
5. Paths with spaces and renamed files in `git status --porcelain` (`R  old -> new`, quoted names): changed-file lists used by `check-changed` and checkpoints must use the new name and survive spaces. Pinned in Task 2.

---

## File Structure

| File | Responsibility |
|---|---|
| `plugins/bearing/bin/brg-guard` (modify) | `format` timing, `stats` median and p90, `stop-gate` prefers `check-changed`, `session` delegates to `brg-session resume` |
| `plugins/bearing/bin/brg-changed` (create) | Print files changed since a marker, one per line, rename-safe |
| `plugins/bearing/bin/brg-session` (create) | `timeline-start`, `timeline-close`, `checkpoint`, `next-step`, `resume` |
| `plugins/bearing/bin/flow-steps.tsv` (generated) | `flow<TAB>order<TAB>skill` from `docs/flows.json`, shipped in the plugin |
| `bin/gen-flow-steps.py` (create) | Generator for the TSV; part of `make docs` and `lint-docs` |
| `plugins/bearing/bin/brg-config` (create) | `get|set <key> [value] [--user]` over `.bearing/config.json` and `bearing.env` |
| `plugins/bearing/bin/brg-update-check` (create) | Cached tag check, snooze and skip |
| `plugins/bearing/bin/brg-learn` (create) | `consent`, `log`, `top`, `list`, `add`, `propose` with redaction |
| `plugins/bearing/bin/brg-doctor` (modify) | `--timing` section, workspace trust check |
| `plugins/bearing/hooks/hooks.json` (modify) | `PreToolUse` matcher `Skill`, `SessionEnd` |
| `plugins/bearing/hooks/scripts/skill-start.sh` (create) | Adapter for the Skill hook |
| `plugins/bearing/hooks/scripts/session-end.sh` (create) | Adapter for SessionEnd |
| `plugins/bearing/hooks/scripts/stop-summary.sh`, `precompact.sh` (modify) | Also write the checkpoint |
| 13 stack `templates*/Makefile` (modify) | `check-changed` target |
| `plugins/bearing/agents/{verifier,critic,security-auditor}.md` (modify) | `model: sonnet` |
| `plugins/bearing/references/console.md` (create) | Question and output contract |
| `plugins/bearing/skills/learn/SKILL.md` (create) | The `learn` skill |
| 29 SKILL.md over 200 lines (modify) + their `references/*.md` (create) | Split |
| 27 SKILL.md that ask in prose (modify) | AskUserQuestion and console.md |
| `Makefile` (modify) | `lint-skill-size`, `lint-questions` in `check`; `gen-flow-steps` in `docs` and `lint-docs` |
| `tests/unit/*.sh` (create) | One test file per new script, named in each task |

---

### Task 0: Confirm the Skill hook carries the skill name

The whole timeline design (Tasks 12 to 14) depends on `PreToolUse` firing for the `Skill` tool with `tool_input.skill`. Prove it before building on it.

**Files:**
- Create (throwaway, not committed): `.scratch/skill-hook-probe/`

- [ ] **Step 1: Write a probe plugin hook**

```bash
mkdir -p .scratch/skill-hook-probe/.claude
cat > .scratch/skill-hook-probe/.claude/settings.json <<'EOF'
{ "hooks": { "PreToolUse": [ { "matcher": "Skill", "hooks": [
  { "type": "command", "command": "cat >> \"$CLAUDE_PROJECT_DIR/probe.jsonl\"; echo >> \"$CLAUDE_PROJECT_DIR/probe.jsonl\"", "timeout": 5 } ] } ] } }
EOF
git -C .scratch/skill-hook-probe init -q
```

- [ ] **Step 2: Run one skill headless**

Run: `cd .scratch/skill-hook-probe && claude -p "Use the bearing:workflow skill to say what comes next." --permission-mode acceptEdits; jq -r '.tool_name, .tool_input' probe.jsonl`
Expected: `Skill` and an object with a `skill` key whose value is `bearing:workflow`.

- [ ] **Step 3: Record the result**

If the payload matches: proceed with Tasks 12 to 14 as written. If `probe.jsonl` is empty or has no `skill` key: stop and tell the user; the fallback (spec B1) is a one-line preamble `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-session" timeline-start <skill>` added only to skills named in `docs/flows.json`, and Task 12 changes accordingly. Delete `.scratch/skill-hook-probe/` either way. No commit.

---

### Task 1: Time the formatter; median and p90 in stats; `doctor --timing`

**Files:**
- Modify: `plugins/bearing/bin/brg-guard` (the `format)` branch near line 1521; `stats)` near line 1768)
- Modify: `plugins/bearing/bin/brg-doctor`
- Test: `tests/unit/guard_timing.sh` (create)

**Interfaces:**
- Produces: `gates.log` lines with gate `format` and outcome `formatted|failed|skipped`; `brg-guard stats` line format `  <gate outcome> <runs>  median <n> ms  p90 <n> ms  max <n> ms`; `brg-doctor --timing` prints the stats block under `timing:`.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/guard_timing.sh: format writes a timed gates.log line; stats
# prints median and p90; doctor --timing prints the stats block.
set -u
. "$(dirname "$0")/../lib/assert.sh"

repo="$(tmpdir)"
git -C "$repo" init -q -b main
mkdir -p "$repo/.bearing/state"
printf 'echo hi\n' > "$repo/a.sh"
in_repo() { ( cd "$repo" && bash "$GUARD" "$@" ) }

t_begin "format logs a timed line"
assert_exit 0 in_repo format "$repo/a.sh"
log="$(cat "$repo/.bearing/state/gates.log")"
assert_contains "$log" "	format	"
t_end

t_begin "stats prints median and p90"
printf '2026-10-16T10:00:0%s\tcheck-file\tclean\t%s\t\n' 1 10 2 20 3 30 4 40 5 1000 > "$repo/.bearing/state/gates.log"
assert_exit 0 in_repo stats
assert_contains "$T_OUT" "check-file clean"
assert_contains "$T_OUT" "median    30 ms"
assert_contains "$T_OUT" "p90  1000 ms"
t_end

t_begin "doctor --timing prints the block"
assert_exit 0 bash -c "cd '$repo' && bash '$KIT/plugins/bearing/bin/brg-doctor' --timing"
assert_contains "$T_OUT" "timing:"
assert_contains "$T_OUT" "check-file clean"
t_end

t_summary
```

`chmod +x tests/unit/guard_timing.sh`

- [ ] **Step 2: Run it to see it fail**

Run: `bash tests/unit/guard_timing.sh`
Expected: FAIL on `format logs a timed line` (no gates.log line) and on `median`.

- [ ] **Step 3: Implement**

In the `format)` branch, set the outcome from `run` and log before `exit 0`:

```bash
  format)
    file="${1:-}"; [ -n "$file" ] && [ -f "$file" ] || exit 0
    root="$(git rev-parse --show-toplevel 2>/dev/null || dirname "$file")"; cd "$root" || exit 0
    fmt_outcome=skipped
    note() { echo "bearing format: $*"; }
    run() { if "$@" >/dev/null 2>&1; then fmt_outcome=formatted; note "$1 formatted ${file##*/}"; else fmt_outcome=failed; note "$1 failed on ${file##*/} (left as written)"; fi; }
```

and replace the branch's final `exit 0;;` with:

```bash
    gate_log format "$fmt_outcome" "${file##*.}"
    exit 0;;
```

Replace the `stats)` aggregation awk with one that sorts durations per key (bash 3.2 safe, POSIX awk):

```bash
    cat "$log.1" "$log" 2>/dev/null | awk -F'\t' '{print $2" "$3"\t"$4}' | sort -t"$(printf '\t')" -k1,1 -k2,2n |
      awk -F'\t' '
        function flush() { if (n) { m=v[int((n+1)/2)]; p=v[int(n*0.9+0.999)]; if (p=="") p=v[n];
          printf "  %-28s %6d  median %5d ms  p90 %5d ms  max %6d ms\n", k, n, m, p, v[n] } }
        $1!=k { flush(); k=$1; n=0 } { v[++n]=$2+0 } END { flush() }'
```

In `brg-doctor`, before the existing argument handling, add:

```bash
if [ "${1:-}" = "--timing" ]; then
  echo "timing:"
  bash "$KIT/bin/brg-guard" stats 2>&1 | sed 's/^/  /'
  exit 0
fi
```

- [ ] **Step 4: Run the test and the existing guard tests**

Run: `bash tests/unit/guard_timing.sh && bash tests/unit/guard_format.sh && bash tests/unit/guard_latency.sh`
Expected: each prints `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/bin/brg-guard plugins/bearing/bin/brg-doctor tests/unit/guard_timing.sh
git commit -m "feat(guard): time the formatter; stats and doctor --timing show median and p90"
```

---

### Task 2: `brg-changed` and a Stop gate that asks for `make check-changed`

**Files:**
- Create: `plugins/bearing/bin/brg-changed`
- Modify: `plugins/bearing/bin/brg-guard` (`stop-gate)` near line 1612)
- Test: `tests/unit/changed_files.sh` (create), extend `tests/unit/guard_harness_gates.sh` only if it asserts the old message text (run it to find out)

**Interfaces:**
- Produces: `brg-changed [--since <marker-file>] [--root <dir>]` prints repository-relative paths of tracked-modified, staged, untracked and renamed-to files, newer than the marker when given and the marker exists, one per line, deduplicated, existing files only. Exit 0 always.
- Produces: Stop gate message `bearing: N file(s) changed in this session since the last check. Run make check-changed and fix what fails before finishing.` when the Makefile has `^check-changed:`; marker for "checked" is the newer of `.check-passed` and `.check-changed-passed`.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/changed_files.sh: brg-changed lists changed files rename-safe and
# space-safe; stop-gate prefers make check-changed and falls back to make check.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHANGED="$KIT/plugins/bearing/bin/brg-changed"

repo="$(tmpdir)"
git -C "$repo" init -q -b main
printf '.bearing/state/\n' > "$repo/.gitignore"
printf 'a\n' > "$repo/old name.txt"; printf 'b\n' > "$repo/keep.txt"
git -C "$repo" add -A; git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q -m init

t_begin "renamed, spaced, untracked and modified files"
git -C "$repo" mv "old name.txt" "new name.txt"
printf 'c\n' > "$repo/fresh.txt"; printf 'b2\n' > "$repo/keep.txt"
assert_exit 0 bash "$CHANGED" --root "$repo"
assert_contains "$T_OUT" "new name.txt"
assert_not_contains "$T_OUT" "old name.txt"
assert_contains "$T_OUT" "fresh.txt"
assert_contains "$T_OUT" "keep.txt"
t_end

t_begin "since a fresh marker nothing is listed"
mkdir -p "$repo/.bearing/state"; sleep 1; touch "$repo/.bearing/state/.check-passed"
assert_exit 0 bash "$CHANGED" --root "$repo" --since "$repo/.bearing/state/.check-passed"
assert_eq "" "$T_OUT"
t_end

sid=s1
in_repo() { ( cd "$repo" && bash "$GUARD" "$@" ) }
t_begin "stop-gate asks for check-changed when the target exists"
touch -t 202001010000 "$repo/.bearing/state/.check-passed"
: > "$repo/.bearing/state/.session-$sid"; touch -t 202001010000 "$repo/.bearing/state/.session-$sid"
printf 'check:\n\t@touch .bearing/state/.check-passed\ncheck-changed:\n\t@true\n' > "$repo/Makefile"
printf 'd\n' > "$repo/fresh.txt"
assert_exit 2 in_repo stop-gate --id "$sid"
assert_contains "$T_OUT" "Run make check-changed"
t_end

t_begin "a check-changed pass satisfies the gate"
sleep 1; touch "$repo/.bearing/state/.check-changed-passed"
assert_exit 0 in_repo stop-gate --id "$sid"
t_end

t_begin "without check-changed the old message stands"
printf 'check:\n\t@touch .bearing/state/.check-passed\n' > "$repo/Makefile"
rm -f "$repo/.bearing/state/.check-changed-passed"; sleep 1; printf 'e\n' > "$repo/fresh.txt"
assert_exit 2 in_repo stop-gate --id "$sid"
assert_contains "$T_OUT" "Run make check and fix what fails"
t_end

t_summary
```

- [ ] **Step 2: Run it to see it fail**

Run: `chmod +x tests/unit/changed_files.sh && bash tests/unit/changed_files.sh`
Expected: FAIL, `brg-changed` does not exist.

- [ ] **Step 3: Write `brg-changed`**

```bash
#!/usr/bin/env bash
# brg-changed: files changed in the working tree (modified, staged, untracked,
# the new name of a rename), repository-relative, one per line. With --since
# <marker>, only files newer than the marker; a missing marker lists all.
# Uses -z so names with spaces, quotes or arrows survive. Exit 0 always.
set -u
root=""; since=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) root="${2:-}"; shift 2 || shift;;
    --since) since="${2:-}"; shift 2 || shift;;
    *) shift;;
  esac
done
[ -n "$root" ] || root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
git -C "$root" status --porcelain -z --untracked-files=all 2>/dev/null |
  tr '\0' '\n' | awk '
    skip { skip=0; next }
    { code=substr($0,1,2); path=substr($0,4) }
    code ~ /^R/ || code ~ /^.R/ || code ~ /^C/ { print path; skip=1; next }
    { print path }' | sort -u | while IFS= read -r f; do
    [ -n "$f" ] && [ -e "$root/$f" ] || continue
    if [ -n "$since" ] && [ -f "$since" ] && ! [ "$root/$f" -nt "$since" ]; then continue; fi
    printf '%s\n' "$f"
  done
exit 0
```

(`git status -z` puts the rename target first and the source as the next NUL field; `skip` drops the source.)

`chmod +x plugins/bearing/bin/brg-changed`

- [ ] **Step 4: Rewrite the counting in `stop-gate`**

Replace the `fresh=0 ... EOF` block and the two message lines with:

```bash
    cc="$state/.check-changed-passed"
    newest="$marker"; [ -f "$cc" ] && { [ ! -f "$marker" ] || [ "$cc" -nt "$marker" ]; } && newest="$cc"
    fresh=0
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      [ "$root/$f" -nt "$start" ] || continue
      fresh=$((fresh+1))
    done <<EOF
$(bash "$(dirname "$0")/brg-changed" --root "$root" --since "$newest")
EOF
    [ "$fresh" -gt 0 ] || { gate_log stop-gate passed; exit 0; }
    target="make check"; grep -qs '^check-changed:' "$root/Makefile" && target="make check-changed"
    msg="bearing: ${fresh} file(s) changed in this session since the last check."
    if [ "$active" -eq 1 ]; then
      echo "$msg Not checked; say so under Not done in the report."
      gate_log stop-gate reminded "$fresh file(s), second stop"
      exit 0
    fi
    echo "$msg Run ${target} and fix what fails before finishing. If it cannot run here, say why under Not done in the report and stop." >&2
    gate_log stop-gate blocked "$fresh file(s), ${target}"
    exit 2;;
```

- [ ] **Step 5: Run the new and the existing gate tests**

Run: `bash tests/unit/changed_files.sh && bash tests/unit/guard_harness_gates.sh && bash tests/unit/guard_session_stop.sh`
Expected: each prints `0 failed`. If `guard_harness_gates.sh` asserted `since make check last passed`, update that assertion to `since the last check` (the only text change) and rerun.

- [ ] **Step 6: Commit**

```bash
git add plugins/bearing/bin/brg-changed plugins/bearing/bin/brg-guard tests/unit/changed_files.sh tests/unit/guard_harness_gates.sh
git commit -m "feat(guard): the Stop gate asks for make check-changed where the Makefile has it"
```

---

### Task 3: `check-changed` in the Go templates

**Files:**
- Modify: `plugins/bearing-backend/skills/go/templates/Makefile`, `plugins/bearing-backend/skills/go/templates-cli/Makefile`
- Test: `tests/unit/check_changed_targets.sh` (create; Tasks 4 to 6 extend it)

**Interfaces:**
- Consumes: the template's existing `STATE` variable (`.bearing/state`), `fmt-check` behaviour.
- Produces, for every stack: target `check-changed` that (a) lists changed files with the same `git status -z` logic as `brg-changed` inlined (scaffolded repos do not have the plugin path), (b) prints `check-changed: 0 files, nothing to check` and exits 0 when none, (c) runs format check, lint and tests scoped to the packages of those files, (d) on success touches `$(STATE)/.check-changed-passed` and prints `check-changed: <F> files, <P> packages checked`, (e) never touches `.check-passed`.

- [ ] **Step 1: Write the failing test (structure only; toolchains are not on every runner)**

```bash
#!/usr/bin/env bash
# tests/unit/check_changed_targets.sh: every stack Makefile template has a
# check-changed target that prints its counts, never writes .check-passed,
# and writes .check-changed-passed. Toolchain runs are in the scaffold job.
set -u
. "$(dirname "$0")/../lib/assert.sh"
n=0
for mk in $(cd "$KIT" && git ls-files 'plugins/*/skills/*/templates*/Makefile'); do
  grep -q 'check-passed' "$KIT/$mk" || continue
  n=$((n+1))
  body="$(awk '/^check-changed:/{p=1;print;next} p&&/^[^\t]/{exit} p' "$KIT/$mk")"
  t_begin "$mk"
  assert_contains "$body" "check-changed:" "target present"
  assert_contains "$body" "0 files, nothing to check" "empty case"
  assert_contains "$body" ".check-changed-passed" "writes its own marker"
  assert_not_contains "$body" "/.check-passed" "never writes the full marker"
  assert_contains "$body" "packages checked" "prints its count"
  t_end
done
t_begin "templates found"
assert_eq 13 "$n" "stack Makefile templates with a check marker"
t_end
t_summary
```

- [ ] **Step 2: Run it to see 13 failures**

Run: `chmod +x tests/unit/check_changed_targets.sh && bash tests/unit/check_changed_targets.sh`
Expected: FAIL for all 13 templates.

- [ ] **Step 3: Add the target to both Go Makefiles (after `check-file:`)**

```make
CHANGED = git status --porcelain -z --untracked-files=all | tr '\0' '\n' | awk 'skip{skip=0;next} {c=substr($$0,1,2);p=substr($$0,4)} c~/^R|^.R|^C/{print p;skip=1;next} {print p}' | sort -u | while IFS= read -r f; do [ -e "$$f" ] || continue; for m in $(STATE)/.check-passed $(STATE)/.check-changed-passed; do [ -f "$$m" ] && ! [ "$$f" -nt "$$m" ] && continue 2; done; printf '%s\n' "$$f"; done

check-changed: ## Format, vet, lint and test only the packages changed since the last check (the Bearing Stop gate runs this; make check stays the full gate)
	@mkdir -p $(STATE); files=$$($(CHANGED) | grep -E '\.go$$|go\.(mod|sum)$$' || true); \
	f=$$(printf '%s' "$$files" | grep -c . || true); \
	[ "$$f" -gt 0 ] || { echo "check-changed: 0 files, nothing to check"; exit 0; }; \
	if printf '%s\n' "$$files" | grep -qE 'go\.(mod|sum)$$'; then pkgs="./..."; p=$$(go list ./... | wc -l | tr -d ' '); \
	else pkgs=$$(printf '%s\n' "$$files" | xargs -n1 dirname | sort -u | sed 's|^|./|'); p=$$(printf '%s\n' "$$pkgs" | wc -l | tr -d ' '); fi; \
	bad=$$(gofmt -l $$(printf '%s\n' "$$files" | grep '\.go$$') 2>/dev/null); [ -z "$$bad" ] || { echo "check-changed: unformatted: $$bad" >&2; exit 1; }; \
	go vet $$pkgs || exit 1; \
	if command -v golangci-lint >/dev/null; then golangci-lint run $$pkgs || exit 1; else echo "check-changed: golangci-lint missing, lint not run"; fi; \
	set -o pipefail; go test -race -count=1 $$pkgs 2>&1 | tail -60 || exit 1; \
	touch $(STATE)/.check-changed-passed; echo "check-changed: $$f files, $$p packages checked"
```

Add `check-changed` to the template's `.PHONY` line.

- [ ] **Step 4: Run the structure test and a real run**

Run: `bash tests/unit/check_changed_targets.sh 2>&1 | grep -c 'go/templates'`
Expected: `0` (no FAIL line mentions the Go templates; other stacks still fail).

Real run (Go installed): `bash plugins/bearing/bin/brg-scaffold go-api Probe --dir "$(mktemp -d)/probe" --host github --tracker none` then in that dir `make setup && make check && echo '// x' >> internal/health/health.go && make check-changed`.
Expected: last line `check-changed: 1 files, 1 packages checked`. If Go is not installed, write "real run not run: go missing" in the commit body.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing-backend/skills/go/templates/Makefile plugins/bearing-backend/skills/go/templates-cli/Makefile tests/unit/check_changed_targets.sh
git commit -m "feat(go): check-changed vets, lints and tests only the changed packages"
```

---

### Task 4: `check-changed` in the Python, Python CLI and data-pipeline templates

**Files:**
- Modify: `plugins/bearing-backend/skills/python/templates/Makefile`, `plugins/bearing-backend/skills/python/templates-cli/Makefile`, `plugins/bearing-backend/skills/data-pipeline/templates/Makefile`
- Test: `tests/unit/check_changed_targets.sh`

**Interfaces:** as Task 3. A "package" here is a test file: a changed `tests/**/test_*.py` is itself; a changed `src/**/<mod>.py` maps to every `tests/**/test_<mod>.py`; a changed `pyproject.toml`, `uv.lock` or `conftest.py` runs the full test target. data-pipeline adds `models/**/*.sql` to sqlfluff.

- [ ] **Step 1: Run the test to see the three Python templates fail**

Run: `bash tests/unit/check_changed_targets.sh 2>&1 | grep -E 'python|data-pipeline'`
Expected: FAIL lines for the three files.

- [ ] **Step 2: Add the target to `python/templates/Makefile` and `python/templates-cli/Makefile` (copy the `CHANGED` variable from Task 3 verbatim above it)**

```make
check-changed: ## ruff format check, ruff check and pytest on the tests for the changed modules only (the Bearing Stop gate runs this; make check stays the full gate)
	@mkdir -p $(STATE); files=$$($(CHANGED) | grep -E '\.py$$|pyproject\.toml$$|uv\.lock$$' || true); \
	f=$$(printf '%s' "$$files" | grep -c . || true); \
	[ "$$f" -gt 0 ] || { echo "check-changed: 0 files, nothing to check"; exit 0; }; \
	py=$$(printf '%s\n' "$$files" | grep '\.py$$' || true); \
	[ -z "$$py" ] || { $(UV) run ruff format --check $$py && $(UV) run ruff check $$py; } || exit 1; \
	if printf '%s\n' "$$files" | grep -qE 'pyproject\.toml$$|uv\.lock$$|conftest\.py$$'; then tests=""; \
	else tests=$$(for x in $$py; do case "$$x" in tests/*test_*.py) echo "$$x";; *) b=$$(basename "$$x" .py); git ls-files -co --exclude-standard "tests/test_$$b.py" "tests/**/test_$$b.py";; esac; done | sort -u); \
	  [ -n "$$tests" ] || { touch $(STATE)/.check-changed-passed; echo "check-changed: $$f files, 0 packages checked (no tests map to them; make check runs all)"; exit 0; }; fi; \
	p=$$(printf '%s' "$$tests" | grep -c . || true); [ -n "$$tests" ] || p=all; \
	set -o pipefail; $(UV) run pytest -m "not integration" $$tests 2>&1 | tail -60 || exit 1; \
	touch $(STATE)/.check-changed-passed; echo "check-changed: $$f files, $$p packages checked"
```

For `templates-cli`, drop `-m "not integration"` (its `test` target has none). For `data-pipeline`, use `-m "not warehouse"`, extend the file grep to `\.py$$|\.sql$$|pyproject\.toml$$|uv\.lock$$`, and before pytest add:

```make
	sql=$$(printf '%s\n' "$$files" | grep '^models/.*\.sql$$' || true); \
	[ -z "$$sql" ] || $(UV) run sqlfluff lint $$sql || exit 1; \
```

Add `check-changed` to each `.PHONY`.

- [ ] **Step 3: Run the structure test**

Run: `bash tests/unit/check_changed_targets.sh 2>&1 | grep -cE 'python|data-pipeline'`
Expected: `0`.

- [ ] **Step 4: Real run (uv installed)**

Scaffold `python-api` as in Task 3, `make setup && make check`, append a comment to one module under `src/`, `make check-changed`.
Expected: `check-changed: 1 files, N packages checked` with N equal to the number of matching `tests/**/test_<mod>.py`, or the "no tests map" line. Not installed: say so in the commit body.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing-backend/skills/python plugins/bearing-backend/skills/data-pipeline/templates/Makefile
git commit -m "feat(python): check-changed runs ruff and only the tests for the changed modules"
```

---

### Task 5: `check-changed` in the Node, React, Next.js and React Native templates

**Files:**
- Modify: `plugins/bearing-backend/skills/node/templates/Makefile`, `plugins/bearing-apps/skills/react/templates/Makefile`, `plugins/bearing-apps/skills/nextjs/templates/Makefile`, `plugins/bearing-apps/skills/react-native/templates/Makefile`
- Test: `tests/unit/check_changed_targets.sh`

**Interfaces:** as Task 3. Scoping uses the runner's own dependency graph: `vitest related --run <files>` (node, react, nextjs) and `jest --findRelatedTests <files>` (react-native). A changed `package.json`, `pnpm-lock.yaml`, `tsconfig*.json`, `vitest.config.*` or `jest.config.*` runs the template's full `test` target. "Packages" counts the test files the runner reported.

- [ ] **Step 1: Confirm four failures**

Run: `bash tests/unit/check_changed_targets.sh 2>&1 | grep -E 'node|react|nextjs'`
Expected: four FAIL lines.

- [ ] **Step 2: Add the target to node, react and nextjs (with the `CHANGED` variable from Task 3)**

```make
check-changed: ## prettier, eslint and the vitest tests related to the changed files only (the Bearing Stop gate runs this; make check stays the full gate)
	@mkdir -p $(STATE); files=$$($(CHANGED) | grep -E '\.(ts|tsx|js|jsx|mjs|cjs|css|json)$$' || true); \
	f=$$(printf '%s' "$$files" | grep -c . || true); \
	[ "$$f" -gt 0 ] || { echo "check-changed: 0 files, nothing to check"; exit 0; }; \
	$(PNPM) exec prettier --check $$files || exit 1; \
	src=$$(printf '%s\n' "$$files" | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$$' || true); \
	[ -z "$$src" ] || $(PNPM) exec eslint --max-warnings 0 $$src || exit 1; \
	if printf '%s\n' "$$files" | grep -qE '(^|/)(package\.json|pnpm-lock\.yaml|tsconfig[^/]*\.json|vitest\.config\.[a-z]+)$$'; then \
	  $(MAKE) --no-print-directory test || exit 1; p=all; \
	else out=$$($(PNPM) exec vitest related --run $$src 2>&1); rc=$$?; printf '%s\n' "$$out" | tail -40; [ $$rc -eq 0 ] || exit 1; \
	  p=$$(printf '%s\n' "$$out" | sed -n 's/.*Test Files *\([0-9][0-9]*\) passed.*/\1/p' | tail -1); p=$${p:-0}; fi; \
	touch $(STATE)/.check-changed-passed; echo "check-changed: $$f files, $$p packages checked"
```

For react-native, replace the test branch with jest:

```make
	else out=$$($(PNPM) exec jest --ci --findRelatedTests $$src --passWithNoTests 2>&1); rc=$$?; printf '%s\n' "$$out" | tail -40; [ $$rc -eq 0 ] || exit 1; \
	  p=$$(printf '%s\n' "$$out" | sed -n 's/^Test Suites:.* \([0-9][0-9]*\) passed.*/\1/p' | tail -1); p=$${p:-0}; fi; \
```

and use `jest\.config\.[a-z]+` in the config regex. Add `check-changed` to each `.PHONY`.

- [ ] **Step 3: Structure test**

Run: `bash tests/unit/check_changed_targets.sh 2>&1 | grep -cE 'node|react|nextjs'`
Expected: `0`.

- [ ] **Step 4: Real run on Next.js (node and pnpm installed)**

Scaffold `nextjs`, `make setup && make check`, touch one component file, `make check-changed`.
Expected: `check-changed: 1 files, N packages checked`, N at least 1 when the component has a test. Not installed: say so in the commit body.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing-backend/skills/node/templates/Makefile plugins/bearing-apps/skills/react/templates/Makefile plugins/bearing-apps/skills/nextjs/templates/Makefile plugins/bearing-apps/skills/react-native/templates/Makefile
git commit -m "feat(js): check-changed lints the changed files and runs only their related tests"
```

---

### Task 6: `check-changed` in Flutter, Android, iOS and infra

**Files:**
- Modify: `plugins/bearing-apps/skills/flutter/templates/Makefile`, `plugins/bearing-apps/skills/android/templates/Makefile`, `plugins/bearing-apps/skills/ios/templates/Makefile`, `plugins/bearing-backend/skills/infra/templates/Makefile`
- Test: `tests/unit/check_changed_targets.sh`

**Interfaces:** as Task 3. Flutter maps `lib/<p>.dart` to `test/<p>_test.dart` plus changed test files. Android and iOS cannot scope cheaply: they run their full `test` target and print `check-changed: <stack> cannot scope, ran all tests` before the count line (spec A1). Infra scopes to Terraform roots (directories of changed `.tf`/`.tfvars`).

- [ ] **Step 1: Confirm four failures**

Run: `bash tests/unit/check_changed_targets.sh 2>&1 | grep -E 'flutter|android|ios|infra'`
Expected: four FAIL lines.

- [ ] **Step 2: Flutter (with the `CHANGED` variable)**

```make
check-changed: ## dart format check, analyze and the tests for the changed Dart files only (the Bearing Stop gate runs this; make check stays the full gate)
	@mkdir -p $(STATE); files=$$($(CHANGED) | grep -E '\.dart$$|pubspec\.(yaml|lock)$$' || true); \
	f=$$(printf '%s' "$$files" | grep -c . || true); \
	[ "$$f" -gt 0 ] || { echo "check-changed: 0 files, nothing to check"; exit 0; }; \
	dart=$$(printf '%s\n' "$$files" | grep '\.dart$$' || true); \
	[ -z "$$dart" ] || { dart format --output=none --set-exit-if-changed $$dart && $(FLUTTER) analyze $$dart; } || exit 1; \
	if printf '%s\n' "$$files" | grep -q 'pubspec'; then $(MAKE) --no-print-directory test || exit 1; p=all; \
	else tests=$$(for x in $$dart; do case "$$x" in test/*_test.dart) echo "$$x";; lib/*) t="test/$${x#lib/}"; t="$${t%.dart}_test.dart"; [ -f "$$t" ] && echo "$$t";; esac; done | sort -u); \
	  p=$$(printf '%s' "$$tests" | grep -c . || true); [ -z "$$tests" ] || $(FLUTTER) test $$tests || exit 1; fi; \
	touch $(STATE)/.check-changed-passed; echo "check-changed: $$f files, $$p packages checked"
```

- [ ] **Step 3: Android and iOS (same body, stack name differs)**

```make
check-changed: ## This stack cannot scope tests cheaply, so the Stop gate runs lint and the full unit tests; make check stays the full gate
	@mkdir -p $(STATE); f=$$($(CHANGED) | grep -c . || true); \
	[ "$$f" -gt 0 ] || { echo "check-changed: 0 files, nothing to check"; exit 0; }; \
	echo "check-changed: android cannot scope, ran all tests"; \
	$(MAKE) --no-print-directory lint test || exit 1; \
	touch $(STATE)/.check-changed-passed; echo "check-changed: $$f files, all packages checked"
```

For iOS use `ios` in the message and `format-check lint test` as the targets.

- [ ] **Step 4: Infra**

```make
check-changed: ## terraform fmt, validate and tflint on the roots of the changed files only (the Bearing Stop gate runs this; make check stays the full gate)
	@mkdir -p $(STATE); files=$$($(CHANGED) | grep -E '\.(tf|tfvars)$$' || true); \
	f=$$(printf '%s' "$$files" | grep -c . || true); \
	[ "$$f" -gt 0 ] || { echo "check-changed: 0 files, nothing to check"; exit 0; }; \
	roots=$$(printf '%s\n' "$$files" | xargs -n1 dirname | sort -u); p=$$(printf '%s\n' "$$roots" | wc -l | tr -d ' '); \
	terraform fmt -check $$files || exit 1; \
	for r in $$roots; do (cd "$$r" && terraform init -backend=false -input=false >/dev/null && terraform validate && tflint) || exit 1; done; \
	touch $(STATE)/.check-changed-passed; echo "check-changed: $$f files, $$p packages checked"
```

Add `check-changed` to each `.PHONY`.

- [ ] **Step 5: Structure test passes for all 13**

Run: `bash tests/unit/check_changed_targets.sh`
Expected: `0 failed` and the `templates found` case passes with 13.

- [ ] **Step 6: Scaffold job**

Run: `bash tests/integration/scaffold_each_stack.sh`
Expected: `0 failed` (the targets parse under make for every stack).

- [ ] **Step 7: Commit**

```bash
git add plugins/bearing-apps/skills/flutter/templates/Makefile plugins/bearing-apps/skills/android/templates/Makefile plugins/bearing-apps/skills/ios/templates/Makefile plugins/bearing-backend/skills/infra/templates/Makefile
git commit -m "feat(apps,infra): check-changed for flutter, android, ios and infra"
```

---

### Task 7: Review agents on Sonnet; Opus by severity

**Files:**
- Modify: `plugins/bearing/agents/verifier.md:6`, `plugins/bearing/agents/critic.md:6`, `plugins/bearing/agents/security-auditor.md:6`
- Modify: `plugins/bearing/skills/branch-review/SKILL.md` (step near line 139), `plugins/bearing/skills/vapt-report/SKILL.md` (near line 84), `plugins/bearing/skills/high-level-design/SKILL.md` (step 9 near line 184)
- Test: `tests/unit/agent_models.sh` (create)

**Interfaces:**
- Produces: agent defaults `verifier: sonnet`, `critic: sonnet`, `security-auditor: sonnet`, `reviewer: opus` (unchanged). Skills pass `model: "opus"` on the Agent call for: a Critical finding's verifier (branch-review), every verifier in vapt-report, critic in graded mode (high-level-design).

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/agent_models.sh: review agents default to sonnet except reviewer;
# the skills that need Opus ask for it by name.
set -u
. "$(dirname "$0")/../lib/assert.sh"
A="$KIT/plugins/bearing/agents"; S="$KIT/plugins/bearing/skills"
t_begin "agent defaults"
for a in verifier critic security-auditor; do assert_contains "$(grep '^model:' "$A/$a.md")" "sonnet" "$a"; done
assert_contains "$(grep '^model:' "$A/reviewer.md")" "opus" "reviewer"
t_end
t_begin "skills ask for opus where severity needs it"
assert_contains "$(cat "$S/branch-review/SKILL.md")" 'model: "opus"' "branch-review Critical"
assert_contains "$(cat "$S/vapt-report/SKILL.md")" 'model: "opus"' "vapt-report"
assert_contains "$(cat "$S/high-level-design/SKILL.md")" 'model: "opus"' "graded critic"
t_end
t_summary
```

- [ ] **Step 2: Run to fail**

Run: `chmod +x tests/unit/agent_models.sh && bash tests/unit/agent_models.sh`
Expected: FAIL on all six.

- [ ] **Step 3: Edit**

In each of the three agent files change `model: opus` to `model: sonnet`.
In branch-review, append to the dispatch step sentence that already says "all in one message so they run in parallel": `Pass model: "opus" on the Agent call for a Critical finding; High findings use the agent's default.`
In vapt-report near line 84 append: `Each verifier call passes model: "opus"; a security sign-off is worth the slower model.`
In high-level-design step 9 append: `Pass model: "opus" on the Agent call in graded mode.`

- [ ] **Step 4: Run test and the review evals' lint**

Run: `bash tests/unit/agent_models.sh && make lint-skills lint-evals`
Expected: `0 failed`; both lints print their counts with 0 problems.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/agents plugins/bearing/skills/branch-review/SKILL.md plugins/bearing/skills/vapt-report/SKILL.md plugins/bearing/skills/high-level-design/SKILL.md tests/unit/agent_models.sh
git commit -m "perf(agents): verifier, critic and security-auditor default to sonnet; opus for Critical, VAPT and graded HLD"
```

---

### Task 8: Workspace trust in doctor and the autopilot preflight

**Files:**
- Modify: `plugins/bearing/bin/brg-doctor` (repository section), `plugins/bearing/bin/brg-autopilot` (preflight)
- Test: `tests/unit/doctor_trust.sh` (create)

**Interfaces:**
- Produces: shell function `trust_state <repo-root> <claude-json>` printing `trusted`, `untrusted <n>` (n = allow entries in `<repo>/.claude/settings.json`), or `unknown`; defined once in `brg-doctor` and called by `brg-autopilot` via `bash brg-doctor --trust-state <root>`.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/doctor_trust.sh: doctor reports an untrusted workspace with the
# number of allow entries Claude Code is ignoring, and the fix.
set -u
. "$(dirname "$0")/../lib/assert.sh"
D="$KIT/plugins/bearing/bin/brg-doctor"
repo="$(tmpdir)"; home="$(tmpdir)"
git -C "$repo" init -q -b main; mkdir -p "$repo/.claude"
printf '{"permissions":{"allow":["Bash(make:*)","Bash(git status:*)"]}}\n' > "$repo/.claude/settings.json"
printf '{"projects":{"%s":{"hasTrustDialogAccepted":false}}}\n' "$repo" > "$home/.claude.json"
t_begin "untrusted"
assert_exit 0 env HOME="$home" bash "$D" --trust-state "$repo"
assert_eq "untrusted 2" "$T_OUT"
t_end
t_begin "trusted"
printf '{"projects":{"%s":{"hasTrustDialogAccepted":true}}}\n' "$repo" > "$home/.claude.json"
assert_exit 0 env HOME="$home" bash "$D" --trust-state "$repo"
assert_eq "trusted" "$T_OUT"
t_end
t_begin "no claude.json"
rm -f "$home/.claude.json"
assert_exit 0 env HOME="$home" bash "$D" --trust-state "$repo"
assert_eq "unknown" "$T_OUT"
t_end
t_summary
```

- [ ] **Step 2: Run to fail**

Run: `chmod +x tests/unit/doctor_trust.sh && bash tests/unit/doctor_trust.sh`
Expected: FAIL (unknown flag).

- [ ] **Step 3: Implement in `brg-doctor` next to `--timing`**

```bash
trust_state() { # <root>: trusted | untrusted <n> | unknown
  local cj="$HOME/.claude.json" n
  [ -f "$cj" ] && command -v jq >/dev/null 2>&1 || { echo unknown; return 0; }
  case "$(jq -r --arg p "$1" '.projects[$p].hasTrustDialogAccepted // "unset"' "$cj" 2>/dev/null)" in
    true) echo trusted;;
    *) n="$(jq -r '.permissions.allow | length' "$1/.claude/settings.json" 2>/dev/null)"; echo "untrusted ${n:-0}";;
  esac
}
if [ "${1:-}" = "--trust-state" ]; then trust_state "${2:-$PWD}"; exit 0; fi
```

In the repository checks section add:

```bash
  ts="$(trust_state "$root")"
  case "$ts" in
    trusted) pass "workspace trusted by Claude Code";;
    untrusted*) fail "workspace not trusted: Claude Code ignores ${ts#untrusted } allow entries, so each command waits on a prompt. Run claude here once and accept the trust dialog";;
    *) optional "workspace trust unknown (no ~/.claude.json or no jq)";;
  esac
```

In `brg-autopilot` preflight, before the first stage:

```bash
ts="$(bash "$(dirname "$0")/brg-doctor" --trust-state "$root")"
case "$ts" in untrusted*) echo "autopilot: workspace not trusted; ${ts#untrusted } allow entries would be ignored and every command would wait. Run claude in $root once and accept the trust dialog, then rerun." >&2; exit 1;; esac
```

- [ ] **Step 4: Run tests**

Run: `bash tests/unit/doctor_trust.sh && bash tests/integration/doctor_matrix.sh && bash tests/unit/autopilot_smoke.sh`
Expected: each `0 failed`. If `doctor_matrix.sh` counts doctor lines, raise its expected count by the one new line.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/bin/brg-doctor plugins/bearing/bin/brg-autopilot tests/unit/doctor_trust.sh tests/integration/doctor_matrix.sh
git commit -m "feat(doctor): report untrusted workspaces; autopilot stops before permission waits"
```

---

### Task 9: `lint-skill-size`

**Files:**
- Modify: `Makefile` (new target; added to `check` only in Task 11)
- Test: `tests/unit/lint_skill_size.sh` (create)

**Interfaces:**
- Produces: `make lint-skill-size` prints `lint-skill-size: <N> skills, largest <path> <lines>` and exits 0, or lists each SKILL.md over 200 lines and exits 1; 0 skills found exits 1.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/lint_skill_size.sh: the size lint fails on a 201-line skill and on
# zero skills, and passes with counts otherwise.
set -u
. "$(dirname "$0")/../lib/assert.sh"
w="$(tmpdir)"; mkdir -p "$w/plugins/p/skills/a"
cp "$KIT/Makefile" "$w/Makefile"
for i in $(seq 1 201); do echo "l$i"; done > "$w/plugins/p/skills/a/SKILL.md"
t_begin "201 lines fails"
assert_exit 2 make -s -C "$w" lint-skill-size
assert_contains "$T_OUT" "plugins/p/skills/a/SKILL.md 201"
t_end
t_begin "200 lines passes with a count"
for i in $(seq 1 200); do echo "l$i"; done > "$w/plugins/p/skills/a/SKILL.md"
assert_exit 0 make -s -C "$w" lint-skill-size
assert_contains "$T_OUT" "lint-skill-size: 1 skills, largest plugins/p/skills/a/SKILL.md 200"
t_end
t_begin "zero skills fails"
rm -rf "$w/plugins/p/skills/a"
assert_exit 2 make -s -C "$w" lint-skill-size
assert_contains "$T_OUT" "0 skills"
t_end
t_summary
```

(`make` exits 2 when a recipe fails.)

- [ ] **Step 2: Run to fail**

Run: `chmod +x tests/unit/lint_skill_size.sh && bash tests/unit/lint_skill_size.sh`
Expected: FAIL, no rule to make target.

- [ ] **Step 3: Add the target**

```make
lint-skill-size: ## Every SKILL.md is 200 lines or fewer; detail goes in the skill's references/ and is read on demand
	@n=0; bad=0; big=""; bl=0; \
	for f in plugins/*/skills/*/SKILL.md; do [ -f "$$f" ] || continue; n=$$((n+1)); l=$$(wc -l < "$$f" | tr -d ' '); \
	  [ "$$l" -le "$$bl" ] || { bl=$$l; big=$$f; }; [ "$$l" -le 200 ] || { echo "over 200 lines: $$f $$l"; bad=$$((bad+1)); }; done; \
	[ "$$n" -gt 0 ] || { echo "lint-skill-size: 0 skills, nothing checked" >&2; exit 1; }; \
	[ "$$bad" -eq 0 ] || { echo "lint-skill-size: $$bad of $$n skills over 200 lines"; exit 1; }; \
	echo "lint-skill-size: $$n skills, largest $$big $$bl"
```

- [ ] **Step 4: Run test; record the real count**

Run: `bash tests/unit/lint_skill_size.sh && make -s lint-skill-size | tail -1`
Expected: test `0 failed`; real run `lint-skill-size: 29 of 106 skills over 200 lines` (exit 2). That 29 is the backlog for Tasks 10 and 11.

- [ ] **Step 5: Commit**

```bash
git add Makefile tests/unit/lint_skill_size.sh
git commit -m "feat(lint): lint-skill-size flags SKILL.md files over 200 lines"
```

---

### Task 10: Split the ten largest skills (spec A4 target: under 150 lines)

**Files (each skill: modify `SKILL.md`, create `references/<topic>.md`):**
`bearing/skills/test-automation`, `bearing/skills/screen-design`, `bearing/skills/high-level-design`, `bearing-apps/skills/flutter`, `bearing/skills/autopilot`, `bearing/skills/ux-flows`, `bearing/skills/health-checks`, `bearing/skills/data-model`, `bearing/skills/backlog`, `bearing/skills/design-system`

**Interfaces:**
- Produces: each SKILL.md keeps frontmatter, the purpose paragraph, Inputs, numbered Steps (one or two lines each, each long step ending `Detail: references/<topic>.md`), Output contract and Gotchas. Moved text is verbatim.

Procedure per skill (one commit per skill):

- [ ] **Step 1: Record the rule inventory before editing**

Run: `grep -nE '^\s*([0-9]+\.|-) ' plugins/<p>/skills/<s>/SKILL.md | wc -l > .scratch/<s>.before` and keep a copy: `cp plugins/<p>/skills/<s>/SKILL.md .scratch/<s>.SKILL.before.md`

- [ ] **Step 2: Move detail**

Move per-step detail paragraphs, long tables, worked examples and per-stack variants verbatim into `references/<topic>.md`, one file per topic, each starting `# <skill>: <topic>` and a one-line "Read when" sentence. In SKILL.md, the step keeps its first sentence and gains `Detail: references/<topic>.md`.

- [ ] **Step 3: Prove nothing was lost**

Run: `cat plugins/<p>/skills/<s>/SKILL.md plugins/<p>/skills/<s>/references/*.md | grep -nE '^\s*([0-9]+\.|-) ' | wc -l` and compare with `.scratch/<s>.before`.
Expected: equal or greater. Then `diff <(tr -s ' \n' '\n\n' < .scratch/<s>.SKILL.before.md | sort -u) <(cat plugins/<p>/skills/<s>/SKILL.md plugins/<p>/skills/<s>/references/*.md | tr -s ' \n' '\n\n' | sort -u) | grep '^<' | head`
Expected: no lines (every word of the old file still exists somewhere).

- [ ] **Step 4: Gates for the skill**

Run: `wc -l plugins/<p>/skills/<s>/SKILL.md && make lint-skills lint-tools lint-evals lint-triggers && bash tests/unit/trigger_eval.sh && bash tests/unit/skill_evals.sh`
Expected: under 150 lines; every lint prints 0 problems; tests `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/<p>/skills/<s>
git commit -m "perf(<s>): keep the steps in SKILL.md, move detail to references/"
```

Repeat for all ten. Then `make docs` and commit regenerated files with `docs: regenerate after skill splits`.

---

### Task 11: Split the other 19 skills over 200 lines; turn on the lint

**Files:** the 19 remaining from Task 9's list: `bearing-apps/skills/react-native`, `bearing/skills/tracker-sync`, `bearing-apps/skills/nextjs`, `bearing/skills/prd`, `bearing/skills/design-directions`, `bearing/skills/feature-flags`, `bearing/skills/onboard-repo`, `bearing/skills/i18n`, `bearing/skills/branch-review`, `bearing/skills/dependency-audit`, `bearing/skills/ab-experiment`, `bearing/skills/release`, `bearing/skills/llm-guardrails`, `bearing-apps/skills/ios`, `bearing-backend/skills/infra`, `bearing/skills/git-hooks`, `bearing-backend/skills/go`, `bearing-backend/skills/data-pipeline`, `bearing/skills/load-test`; plus `Makefile` (`check:` line).

- [ ] **Step 1: Apply Task 10's Steps 1 to 5 to each skill**, target 200 lines or fewer (not 150). One commit per skill.

- [ ] **Step 2: Add the lint to the gate**

In `Makefile`, add `lint-skill-size` to the `check:` prerequisites after `lint-skills`.

- [ ] **Step 3: Run the gate**

Run: `make -s lint-skill-size && make check 2>&1 | tail -3`
Expected: `lint-skill-size: 106 skills, largest <path> <n>` with n at most 200; `check: passed`.

- [ ] **Step 4: Commit**

```bash
git add Makefile docs site devguide
git commit -m "build: lint-skill-size joins make check"
```

---

### Task 12: Skill timeline from a `PreToolUse` hook

**Files:**
- Create: `plugins/bearing/bin/brg-session`, `plugins/bearing/hooks/scripts/skill-start.sh`
- Modify: `plugins/bearing/hooks/hooks.json`, `plugins/bearing/hooks/scripts/stop-summary.sh`
- Test: `tests/unit/session_timeline.sh` (create)

**Interfaces:**
- Produces: `brg-session timeline-start --id <sid> --skill <name>` appends `{"ts":"<iso>","epoch":<unix seconds>,"session":"<sid>","branch":"<b>","skill":"<name>","event":"start"}` and, if the same session has an open start, first appends `{"…","skill":"<previous>","event":"end"}`. `brg-session timeline-close --id <sid>` appends `end` for the open skill. `brg-session timeline-recent [--branch <b>] [--n 3]` prints skill names of the last N ended entries on that branch, newest last. File: `<root>/.bearing/state/timeline.jsonl`; rotated to `.1` past 524288 bytes. Needs `.bearing/` to exist, else no-op. Exit 0 always.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/session_timeline.sh: timeline start, implicit end, close, recent,
# no-op outside a Bearing repo, and a branch without a task id.
set -u
. "$(dirname "$0")/../lib/assert.sh"
S="$KIT/plugins/bearing/bin/brg-session"
repo="$(tmpdir)"; git -C "$repo" init -q -b feat/RuntimeAndFeel; mkdir -p "$repo/.bearing/state"
in_repo() { ( cd "$repo" && bash "$S" "$@" ) }
tl="$repo/.bearing/state/timeline.jsonl"

t_begin "start, implicit end, close"
assert_exit 0 in_repo timeline-start --id s1 --skill bearing:start-task
assert_exit 0 in_repo timeline-start --id s1 --skill bearing:test-cases
assert_exit 0 in_repo timeline-close --id s1
assert_eq 4 "$(wc -l < "$tl" | tr -d ' ')" "four events"
assert_contains "$(sed -n 2p "$tl")" '"skill":"bearing:start-task","event":"end"'
assert_contains "$(sed -n 4p "$tl")" '"skill":"bearing:test-cases","event":"end"'
t_end

t_begin "recent lists ended skills on the branch, newest last"
assert_exit 0 in_repo timeline-recent --n 3
assert_eq "bearing:start-task
bearing:test-cases" "$T_OUT"
t_end

t_begin "no .bearing directory is a silent no-op"
other="$(tmpdir)"; git -C "$other" init -q -b main
assert_exit 0 bash -c "cd '$other' && bash '$S' timeline-start --id s1 --skill x"
assert_eq "" "$T_OUT"
[ ! -e "$other/.bearing" ]; assert_eq 0 $? "nothing created"
t_end

t_summary
```

- [ ] **Step 2: Run to fail**

Run: `chmod +x tests/unit/session_timeline.sh && bash tests/unit/session_timeline.sh`
Expected: FAIL, script missing.

- [ ] **Step 3: Write `brg-session` (timeline part)**

```bash
#!/usr/bin/env bash
# brg-session: session memory for Bearing, all local and model-free.
#   timeline-start --id <sid> --skill <name>   record a skill start (ends the open one)
#   timeline-close --id <sid>                   end the open skill of this session
#   timeline-recent [--branch <b>] [--n <k>]    last k ended skills on the branch
#   checkpoint                                  write .bearing/state/<branch>.checkpoint.md
#   next-step                                   the next flow step after the timeline
#   resume [--source startup|resume|compact]    the block SessionStart prints
# Runs on bash 3.2; needs git; uses jq when present. Exit 0 always.
set -u
sub="${1:-}"; shift || true
id=""; skill=""; branch=""; n=3; source=""
while [ $# -gt 0 ]; do
  case "$1" in
    --id) id="${2:-}"; shift 2 || shift;;
    --skill) skill="${2:-}"; shift 2 || shift;;
    --branch) branch="${2:-}"; shift 2 || shift;;
    --n) n="${2:-3}"; shift 2 || shift;;
    --source) source="${2:-}"; shift 2 || shift;;
    *) shift;;
  esac
done
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -d "$root/.bearing" ] || exit 0
st="$root/.bearing/state"; mkdir -p "$st"; tl="$st/timeline.jsonl"
[ -n "$branch" ] || branch="$(git -C "$root" branch --show-current 2>/dev/null)"; branch="${branch:-detached}"
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
event() { # <skill> <start|end>
  [ -f "$tl" ] && [ "$(wc -c < "$tl" | tr -d ' ')" -gt 524288 ] && mv -f "$tl" "$tl.1"
  printf '{"ts":"%s","epoch":%s,"session":"%s","branch":"%s","skill":"%s","event":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(date +%s)" "$(esc "$id")" "$(esc "$branch")" "$(esc "$1")" "$2" >> "$tl"
}
open_skill() { # the skill this session started and has not ended
  [ -f "$tl" ] || return 0
  grep "\"session\":\"$(esc "$id")\"" "$tl" | tail -1 | grep '"event":"start"' | sed 's/.*"skill":"\([^"]*\)".*/\1/'
}
case "$sub" in
  timeline-start)
    [ -n "$skill" ] || exit 0
    prev="$(open_skill)"; [ -z "$prev" ] || event "$prev" end
    event "$skill" start;;
  timeline-close)
    prev="$(open_skill)"; [ -z "$prev" ] || event "$prev" end;;
  timeline-recent)
    [ -f "$tl" ] || exit 0
    cat "$tl.1" "$tl" 2>/dev/null | grep "\"branch\":\"$(esc "$branch")\"" | grep '"event":"end"' |
      sed 's/.*"skill":"\([^"]*\)".*/\1/' | tail -n "$n";;
esac
exit 0
```

`chmod +x plugins/bearing/bin/brg-session`

- [ ] **Step 4: Adapter and hook registration**

`plugins/bearing/hooks/scripts/skill-start.sh`:

```bash
#!/usr/bin/env bash
# PreToolUse (Skill): record which skill started, for resume and the menu.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
s="$(json_field tool_input.skill)"; [ "$s" != "__BRG_UNPARSED__" ] || exit 0
exec bash "$(dirname "$0")/../../bin/brg-session" timeline-start --id "$(json_field session_id)" --skill "$s"
```

In `hooks.json`, add to `PreToolUse` a second entry:

```json
      {
        "matcher": "Skill",
        "hooks": [
          { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/scripts/skill-start.sh\"", "timeout": 5 }
        ]
      }
```

In `stop-summary.sh`, before `block_or_print`, add:

```bash
bash "$(dirname "$0")/../../bin/brg-session" timeline-close --id "$(json_field session_id)" >/dev/null 2>&1
```

`chmod +x plugins/bearing/hooks/scripts/skill-start.sh`

- [ ] **Step 5: Run tests**

Run: `bash tests/unit/session_timeline.sh && make lint-shell lint-json lint-portable && bash tests/integration/harness_each.sh`
Expected: `0 failed`; lints print counts with 0 problems.

- [ ] **Step 6: Commit**

```bash
git add plugins/bearing/bin/brg-session plugins/bearing/hooks tests/unit/session_timeline.sh
git commit -m "feat(session): record a skill timeline from a PreToolUse Skill hook"
```

---

### Task 13: Automatic checkpoint on Stop and PreCompact

**Files:**
- Modify: `plugins/bearing/bin/brg-session` (add `checkpoint`), `plugins/bearing/hooks/scripts/stop-summary.sh`, `plugins/bearing/hooks/scripts/precompact.sh`
- Test: `tests/unit/session_checkpoint.sh` (create)

**Interfaces:**
- Consumes: `timeline-recent` (Task 12); `next-step` (Task 14; until then the line prints `Next flow step: unknown`).
- Produces: `<root>/.bearing/state/<branch with / as _>.checkpoint.md` with lines `Task: <ID|none>`, `Branch: <b>`, `Base: <ref> <short sha>`, `Ahead/behind: <a>/<b>`, `Uncommitted: <n> file(s)`, `Recent skills: <a, b, c|none>`, `Next flow step: <skill|unknown>`, `Next (from state file): <text|none>`. Logs `gate_log`-style line `checkpoint written <ms>` to `gates.log`.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/session_checkpoint.sh: checkpoint content on a task branch and on
# a branch without an id.
set -u
. "$(dirname "$0")/../lib/assert.sh"
S="$KIT/plugins/bearing/bin/brg-session"
repo="$(tmpdir)"; git -C "$repo" init -q -b main
printf '.bearing/state/\n' > "$repo/.gitignore"; git -C "$repo" add -A
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q -m init
git -C "$repo" checkout -q -b feature/TASK-7-widgets; mkdir -p "$repo/.bearing/state"
printf '# Handoff\nNext: wire the list.\n' > "$repo/.bearing/state/feature_TASK-7-widgets.md"
printf 'x\n' > "$repo/a.txt"
in_repo() { ( cd "$repo" && bash "$S" "$@" ) }
cp="$repo/.bearing/state/feature_TASK-7-widgets.checkpoint.md"

t_begin "task branch"
in_repo timeline-start --id s --skill bearing:start-task; in_repo timeline-close --id s
assert_exit 0 in_repo checkpoint
c="$(cat "$cp")"
assert_contains "$c" "Task: TASK-7"
assert_contains "$c" "Uncommitted: 1 file(s)"
assert_contains "$c" "Recent skills: bearing:start-task"
assert_contains "$c" "Next (from state file): wire the list."
t_end

t_begin "branch with no task id"
git -C "$repo" checkout -q -b feat/RuntimeAndFeel
assert_exit 0 in_repo checkpoint
assert_contains "$(cat "$repo/.bearing/state/feat_RuntimeAndFeel.checkpoint.md")" "Task: none"
t_end
t_summary
```

- [ ] **Step 2: Run to fail**

Run: `chmod +x tests/unit/session_checkpoint.sh && bash tests/unit/session_checkpoint.sh`
Expected: FAIL, no checkpoint file.

- [ ] **Step 3: Implement `checkpoint` in `brg-session` (add before the closing `esac`)**

```bash
  checkpoint)
    t0="$(date +%s)"
    task="$(printf '%s' "$branch" | grep -oE '[A-Z][A-Z0-9]*(-[0-9]+)+' | head -1)"
    base="$(git -C "$root" rev-parse -q --verify origin/HEAD >/dev/null 2>&1 && echo origin/HEAD || echo main)"
    bsha="$(git -C "$root" rev-parse --short "$base" 2>/dev/null || echo none)"
    ab="$(git -C "$root" rev-list --left-right --count "$base...HEAD" 2>/dev/null | awk '{print $2"/"$1}')"
    unc="$(git -C "$root" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    recent="$(bash "$0" timeline-recent --branch "$branch" --n 3 | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
    nxt="$(bash "$0" next-step --branch "$branch" 2>/dev/null)"
    sf="$st/$(printf '%s' "$branch" | tr '/' '_').md"
    sn="$( [ -f "$sf" ] && grep -m1 '^Next:' "$sf" | sed 's/^Next: *//')"
    out="$st/$(printf '%s' "$branch" | tr '/' '_').checkpoint.md"
    {
      echo "# Checkpoint $(date -u '+%Y-%m-%d %H:%M') UTC"
      echo "Task: ${task:-none}"
      echo "Branch: $branch"
      echo "Base: $base $bsha"
      echo "Ahead/behind: ${ab:-0/0}"
      echo "Uncommitted: $unc file(s)"
      echo "Recent skills: ${recent:-none}"
      echo "Next flow step: ${nxt:-unknown}"
      echo "Next (from state file): ${sn:-none}"
    } > "$out.tmp" && mv "$out.tmp" "$out"
    printf '%s\tcheckpoint\twritten\t%s\t\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$(( ($(date +%s) - t0) * 1000 ))" >> "$st/gates.log";;
```

Hook adapters, appended as the first command after sourcing lib.sh in both `stop-summary.sh` and `precompact.sh`:

```bash
bash "$(dirname "$0")/../../bin/brg-session" checkpoint >/dev/null 2>&1
```

- [ ] **Step 4: Run tests**

Run: `bash tests/unit/session_checkpoint.sh && bash tests/unit/guard_session_stop.sh && bash tests/unit/guard_latency.sh`
Expected: `0 failed` each; `guard_latency.sh` still within its budget.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/bin/brg-session plugins/bearing/hooks/scripts tests/unit/session_checkpoint.sh
git commit -m "feat(session): write a checkpoint on every Stop and before compaction"
```

---

### Task 14: Flow steps in the plugin; next step; automatic resume

**Files:**
- Create: `bin/gen-flow-steps.py`, `plugins/bearing/bin/flow-steps.tsv` (generated)
- Modify: `Makefile` (`docs` and `lint-docs`), `plugins/bearing/bin/brg-session` (`next-step`, `resume`), `plugins/bearing/bin/brg-guard` (`session)` calls `resume`)
- Test: `tests/unit/session_resume.sh` (create)

**Interfaces:**
- Produces: `flow-steps.tsv` lines `<flow-id>\t<order>\t<skill>` for every step with a `skill` in `docs/flows.json`, depth-first through branches (all options, in file order), skills normalised to their bare name (`bearing:x` and `/x` become `x`), duplicates within a flow kept at first position.
- Produces: `brg-session next-step [--branch b]` picks the flow from the branch prefix (`bugfix/` or `fix/` or `hotfix/` -> `bugfix`; `feature/` or `feat/` -> `feature`; otherwise `feature`), takes the highest order among the branch's ended skills that appear in the flow, prints the next skill after it, or the flow's first skill when none matched.
- Produces: `brg-session resume` prints at most 40 lines: the checkpoint body (from line 2), then `Resume <ID|this branch>: last ran <skill|nothing yet>. Next: <skill>. Ask the user with AskUserQuestion whether to continue with it.`

- [ ] **Step 1: Write the generator**

```python
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
```

In `Makefile`, add `python3 bin/gen-flow-steps.py` to the `docs:` recipe and to the `lint-docs` generator line, and add `plugins/bearing/bin/flow-steps.tsv` to both of `lint-docs`'s file lists. Run `python3 bin/gen-flow-steps.py`.
Expected: `gen-flow-steps: <n> flows, <m> steps` with n and m above 0.

- [ ] **Step 2: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/session_resume.sh: next step from the timeline and the resume
# block, with and without a task id.
set -u
. "$(dirname "$0")/../lib/assert.sh"
S="$KIT/plugins/bearing/bin/brg-session"
repo="$(tmpdir)"; git -C "$repo" init -q -b main
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
git -C "$repo" checkout -q -b bugfix/TASK-9-crash; mkdir -p "$repo/.bearing/state"
in_repo() { ( cd "$repo" && bash "$S" "$@" ) }
first="$(awk -F'\t' '$1=="bugfix" && $2==1 {print $3}' "$KIT/plugins/bearing/bin/flow-steps.tsv")"
second="$(awk -F'\t' '$1=="bugfix" && $2==2 {print $3}' "$KIT/plugins/bearing/bin/flow-steps.tsv")"

t_begin "nothing ran: next is the first bugfix step"
assert_exit 0 in_repo next-step
assert_eq "$first" "$T_OUT"
t_end

t_begin "after the first step, next is the second"
in_repo timeline-start --id s --skill "bearing:$first"; in_repo timeline-close --id s
assert_exit 0 in_repo next-step
assert_eq "$second" "$T_OUT"
t_end

t_begin "resume block"
assert_exit 0 in_repo resume --source startup
assert_contains "$T_OUT" "Resume TASK-9: last ran bearing:$first. Next: $second."
assert_eq 1 "$([ "$(printf '%s\n' "$T_OUT" | wc -l)" -le 40 ] && echo 1 || echo 0)" "at most 40 lines"
t_end

t_begin "branch without an id"
git -C "$repo" checkout -q -b feat/RuntimeAndFeel
assert_exit 0 in_repo resume --source startup
assert_contains "$T_OUT" "Resume this branch: last ran nothing yet."
assert_not_contains "$T_OUT" "Resume :"
t_end
t_summary
```

- [ ] **Step 3: Run to fail**

Run: `chmod +x tests/unit/session_resume.sh && bash tests/unit/session_resume.sh`
Expected: FAIL on `next-step` output.

- [ ] **Step 4: Implement `next-step` and `resume` in `brg-session`**

```bash
  next-step)
    steps="$(dirname "$0")/flow-steps.tsv"; [ -f "$steps" ] || exit 0
    case "$branch" in bugfix/*|fix/*|hotfix/*) flow=bugfix;; *) flow=feature;; esac
    done_list="$(bash "$0" timeline-recent --branch "$branch" --n 200 | sed 's/.*://; s|^/||')"
    best=0
    for s in $done_list; do
      o="$(awk -F'\t' -v f="$flow" -v s="$s" '$1==f && $3==s {print $2; exit}' "$steps")"
      [ -n "$o" ] && [ "$o" -gt "$best" ] && best="$o"
    done
    awk -F'\t' -v f="$flow" -v b="$best" '$1==f && $2==b+1 {print $3; exit}' "$steps";;
  resume)
    bash "$0" checkpoint >/dev/null 2>&1
    cpf="$st/$(printf '%s' "$branch" | tr '/' '_').checkpoint.md"
    [ -f "$cpf" ] && sed -n '2,12p' "$cpf"
    task="$(printf '%s' "$branch" | grep -oE '[A-Z][A-Z0-9]*(-[0-9]+)+' | head -1)"
    last="$(bash "$0" timeline-recent --branch "$branch" --n 1)"
    nxt="$(bash "$0" next-step --branch "$branch")"
    echo "Resume ${task:-this branch}: last ran ${last:-nothing yet}. Next: ${nxt:-see the workflow skill}. Ask the user with AskUserQuestion whether to continue with it."
    ;;
```

In `brg-guard session)`, replace the two lines that print the handoff state file's first 20 lines with:

```bash
    [ -f "$sf" ] && { echo "Handoff state from the previous session (${sf#"$root"/}):"; head -8 "$sf"; }
    [ "$source" = "compact" ] || bash "$(dirname "$0")/brg-session" resume --source "${source:-startup}" 2>/dev/null
```

- [ ] **Step 5: Run tests**

Run: `bash tests/unit/session_resume.sh && bash tests/unit/guard_session_stop.sh && make lint-docs`
Expected: `0 failed`; `guard_session_stop.sh` still finds `Next: wire the widget list.` (within the first 8 lines); `lint-docs` passes.

- [ ] **Step 6: Commit**

```bash
git add bin/gen-flow-steps.py plugins/bearing/bin/flow-steps.tsv plugins/bearing/bin/brg-session plugins/bearing/bin/brg-guard Makefile tests/unit/session_resume.sh
git commit -m "feat(session): resume prints the checkpoint and the next flow step at startup"
```

---

### Task 15: Tracked progress at session end

**Files:**
- Create: `plugins/bearing/hooks/scripts/session-end.sh`
- Modify: `plugins/bearing/hooks/hooks.json`
- Test: `tests/unit/session_end.sh` (create)

**Interfaces:**
- Consumes: `progress.py write --task <ID> --next <text>` (existing), the checkpoint (Task 13).
- Produces: at `SessionEnd`, when the branch has a task id, `docs/progress/<ID>.md` gets `--next` from the checkpoint's `Next flow step` (or `Next (from state file)` when that is set) and `--branch`. Never commits. No task id: no-op.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/session_end.sh: SessionEnd writes docs/progress/<ID>.md on a task
# branch and nothing on a branch without an id.
set -u
. "$(dirname "$0")/../lib/assert.sh"
H="$KIT/plugins/bearing/hooks/scripts/session-end.sh"
repo="$(tmpdir)"; git -C "$repo" init -q -b main
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
git -C "$repo" checkout -q -b feature/TASK-3-list; mkdir -p "$repo/.bearing/state"
t_begin "task branch"
T_IN='{"session_id":"s","reason":"exit"}'
assert_exit 0 bash -c "cd '$repo' && bash '$H'"
assert_file "$repo/docs/progress/TASK-3.md"
assert_eq "" "$(git -C "$repo" log --oneline -1 -- docs/progress)" "nothing committed"
t_end
t_begin "no task id"
git -C "$repo" checkout -q -b feat/Thing
assert_exit 0 bash -c "cd '$repo' && bash '$H'"
assert_eq 1 "$(ls "$repo/docs/progress" | wc -l | tr -d ' ')" "still one file"
t_end
t_summary
```

- [ ] **Step 2: Run to fail**

Run: `chmod +x tests/unit/session_end.sh && bash tests/unit/session_end.sh`
Expected: FAIL, script missing.

- [ ] **Step 3: Implement**

```bash
#!/usr/bin/env bash
# SessionEnd: refresh docs/progress/<ID>.md from the checkpoint so a teammate
# sees where this task stands after the engineer commits and pushes. Never
# commits. Branches without a task id are left alone.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
root="$(repo_root)" || exit 0
task="$(task_id_from_branch)"; [ -n "$task" ] || exit 0
kit="$(dirname "$0")/../.."
bash "$kit/bin/brg-session" checkpoint >/dev/null 2>&1
cpf="$root/.bearing/state/$(current_branch | tr '/' '_').checkpoint.md"
nxt="$(sed -n 's/^Next (from state file): //p' "$cpf" 2>/dev/null)"
[ -n "$nxt" ] && [ "$nxt" != none ] || nxt="$(sed -n 's/^Next flow step: //p' "$cpf" 2>/dev/null)"
cd "$root" && python3 "$kit/skills/session-handoff/scripts/progress.py" write --task "$task" --branch "$(current_branch)" --next "${nxt:-unknown}" >/dev/null 2>&1
exit 0
```

`hooks.json` gains:

```json
    "SessionEnd": [
      {
        "hooks": [
          { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/scripts/session-end.sh\"", "timeout": 5 }
        ]
      }
    ]
```

`chmod +x plugins/bearing/hooks/scripts/session-end.sh`

- [ ] **Step 4: Run tests**

Run: `bash tests/unit/session_end.sh && bash tests/unit/progress.sh && make lint-json lint-shell`
Expected: `0 failed`; lints 0 problems.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/hooks tests/unit/session_end.sh
git commit -m "feat(session): SessionEnd refreshes docs/progress for the task branch"
```

---

### Task 16: `start-task` reads the branch instead of asking; config helper; console contract

**Files:**
- Create: `plugins/bearing/bin/brg-config`, `plugins/bearing/references/console.md`
- Modify: `plugins/bearing/skills/start-task/SKILL.md` (Inputs), `plugins/bearing/skills/session-handoff/SKILL.md` (mention automatic checkpoint)
- Test: `tests/unit/config_helper.sh` (create)

**Interfaces:**
- Produces: `brg-config get <key> [--user]` prints the value or nothing, exit 0. `brg-config set <key> <value> [--user]` writes atomically. Project scope: `<root>/.bearing/config.json` (flat JSON object, created `{}` when absent; needs jq; without jq prints `brg-config: jq required` to stderr and exits 1). User scope: `bearing.env` line `KEY=value` (key upper-cased, `-` to `_`), replacing an existing line.
- Produces: `console.md` (contract text below), cited by skills as `plugins/bearing/references/console.md` via `${CLAUDE_PLUGIN_ROOT}/references/console.md`.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/config_helper.sh: project and user answers round-trip.
set -u
. "$(dirname "$0")/../lib/assert.sh"
C="$KIT/plugins/bearing/bin/brg-config"
repo="$(tmpdir)"; cfg="$(tmpdir)"; git -C "$repo" init -q -b main; mkdir -p "$repo/.bearing"
run() { ( cd "$repo" && XDG_CONFIG_HOME="$cfg" bash "$C" "$@" ) }
t_begin "project round trip"
assert_exit 0 run set design.buildPath code
assert_exit 0 run get design.buildPath
assert_eq "code" "$T_OUT"
assert_contains "$(cat "$repo/.bearing/config.json")" '"design.buildPath": "code"'
t_end
t_begin "user round trip replaces"
assert_exit 0 run set update-skip v0.8.0 --user
assert_exit 0 run set update-skip v0.9.0 --user
assert_exit 0 run get update-skip --user
assert_eq "v0.9.0" "$T_OUT"
assert_eq 1 "$(grep -c '^BEARING_UPDATE_SKIP=' "$cfg/bearing/bearing.env")" "one line"
t_end
t_begin "missing key is empty"
assert_exit 0 run get nothing.here
assert_eq "" "$T_OUT"
t_end
t_summary
```

- [ ] **Step 2: Run to fail**

Run: `chmod +x tests/unit/config_helper.sh && bash tests/unit/config_helper.sh`
Expected: FAIL, script missing.

- [ ] **Step 3: Write `brg-config`**

```bash
#!/usr/bin/env bash
# brg-config: remembered answers. Project answers (shared, committed) in
# .bearing/config.json; personal answers in bearing.env as BEARING_<KEY>.
#   brg-config get <key> [--user]
#   brg-config set <key> <value> [--user]
set -u
op="${1:-}"; key="${2:-}"; val=""; user=0
shift 2 2>/dev/null || true
for a in "$@"; do case "$a" in --user) user=1;; *) [ -z "$val" ] && val="$a";; esac; done
[ -n "$op" ] && [ -n "$key" ] || { echo "usage: brg-config get|set <key> [value] [--user]" >&2; exit 2; }
if [ "$user" -eq 1 ]; then
  dir="${XDG_CONFIG_HOME:-$HOME/.config}/bearing"; envf="$dir/bearing.env"
  k="BEARING_$(printf '%s' "$key" | tr 'a-z.-' 'A-Z__')"
  case "$op" in
    get) [ -f "$envf" ] && grep -E "^$k=" "$envf" | tail -1 | cut -d= -f2-; exit 0;;
    set) mkdir -p "$dir"; { [ -f "$envf" ] && grep -vE "^$k=" "$envf"; echo "$k=$val"; } > "$envf.tmp" && mv "$envf.tmp" "$envf"; chmod 600 "$envf"; exit 0;;
  esac
fi
command -v jq >/dev/null 2>&1 || { echo "brg-config: jq required" >&2; exit 1; }
root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "brg-config: not a git repository" >&2; exit 1; }
f="$root/.bearing/config.json"; mkdir -p "$root/.bearing"; [ -f "$f" ] || echo '{}' > "$f"
case "$op" in
  get) jq -r --arg k "$key" '.[$k] // empty' "$f";;
  set) jq --arg k "$key" --arg v "$val" '.[$k] = $v' "$f" > "$f.tmp" && mv "$f.tmp" "$f";;
  *) echo "brg-config: unknown op $op" >&2; exit 2;;
esac
exit 0
```

`chmod +x plugins/bearing/bin/brg-config`

- [ ] **Step 4: Write `plugins/bearing/references/console.md`**

```markdown
# Console contract

Every Bearing skill that asks or reports follows this. It exists so a
session feels like one product.

## Asking

1. Infer first. Read the repository, `.bearing/config.json`
   (`brg-config get <key>`) and `bearing.env` (`brg-config get <key> --user`).
   A recorded answer is used silently; do not ask it again.
2. Confirm inferences instead of asking open questions: "I found a Go
   service with Postgres. Correct?"
3. Ask with AskUserQuestion: at most three questions a round, two to four
   options each, the recommended option first with "(Recommended)" in its
   label, and one sentence per option that states the trade-off in plain
   words a newcomer understands.
4. Record the answer with `brg-config set` (project facts) or
   `brg-config set ... --user` (personal preferences). A recommendation the
   user did not pick is never recorded as their answer. No answer: record
   nothing and say in one line which default this run uses.
5. Prose fallback only when AskUserQuestion is unavailable; say so in one
   line, then ask the same options as a numbered list.

## Reporting

Lead with the result in one or two sentences, then the AGENTS.md shape:
Changed, Verified, Not done, Noticed. Every number comes from a command
that ran. No tours of every edit, no restated plan.
```

- [ ] **Step 5: Update `start-task` Inputs**

Replace the task id bullet with:

```markdown
- task id: `and`, or the id in the request; else the id in the current
  branch name when it matches the prefix (then report existing work, do not
  ask); else ask once with AskUserQuestion as
  `${CLAUDE_PLUGIN_ROOT}/references/console.md` says.
```

Add `AskUserQuestion` and `Bash(bash *bin/brg-config*)` to its `allowed-tools`. In `session-handoff/SKILL.md`, add one line under its purpose: `Checkpoints are written automatically on every Stop and at SessionEnd; run this skill for a written handoff a person will read.`

- [ ] **Step 6: Run tests and lints**

Run: `bash tests/unit/config_helper.sh && make lint-skills lint-tools lint-prose`
Expected: `0 failed`; lints 0 problems.

- [ ] **Step 7: Commit**

```bash
git add plugins/bearing/bin/brg-config plugins/bearing/references/console.md plugins/bearing/skills/start-task/SKILL.md plugins/bearing/skills/session-handoff/SKILL.md tests/unit/config_helper.sh
git commit -m "feat(console): brg-config remembers answers; console.md is the question contract; start-task reads the branch"
```

---

### Task 17: Update check

**Files:**
- Create: `plugins/bearing/bin/brg-update-check`
- Modify: `plugins/bearing/bin/brg-guard` (`session)` on `startup` only)
- Test: `tests/unit/update_check.sh` (create)

**Interfaces:**
- Produces: `brg-update-check [--remote <url>] [--installed <ver>] [--budget <s>]` prints `BEARING_UPDATE: <installed> -> <newest>` followed by up to 8 lines of that version's `CHANGELOG.md` section when a local CHANGELOG has it (a source checkout), else the line `See CHANGELOG.md at <remote>`; or prints nothing. Only `git ls-remote` touches the network; no fetch. Cache file `${XDG_CONFIG_HOME:-$HOME/.config}/bearing/update-check` holds `<epoch>\t<newest>`; fresh for 86400 s. Respects `BEARING_UPDATE_CHECK=off`, `BEARING_UPDATE_SKIP=<ver>`, `BEARING_UPDATE_SNOOZE_UNTIL=<epoch>` (env, then `bearing.env`). Remote defaults to the `bearing` entry in `~/.claude/plugins/known_marketplaces.json` (`.bearing.source.url`), installed defaults to `brg-guard --version`. Exit 0 always; timeout or failure logs `update-check not-run <reason>` to `gates.log` when a `.bearing/` exists and prints nothing.
- Produces: an `UPDATE_PROMPT` line appended by `brg-guard session` after the version line: `Bearing <new> is available (you have <old>). Ask the user with AskUserQuestion: Upgrade now (run the upgrade-tools skill) / Remind me tomorrow (brg-config set update-snooze-until <now+86400> --user) / Skip this version (brg-config set update-skip <new> --user).`

- [ ] **Step 1: Write the failing test (local bare repo as the remote)**

```bash
#!/usr/bin/env bash
# tests/unit/update_check.sh: newer, same, offline, snoozed, skipped, off.
set -u
. "$(dirname "$0")/../lib/assert.sh"
U="$KIT/plugins/bearing/bin/brg-update-check"
remote="$(tmpdir)/r.git"; git init -q --bare "$remote"
w="$(tmpdir)"; git -C "$w" init -q -b main
git -C "$w" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m a
git -C "$w" tag v0.7.0; git -C "$w" tag v0.8.0; git -C "$w" push -q "$remote" --tags
cfg="$(tmpdir)"
run() { XDG_CONFIG_HOME="$cfg" bash "$U" --remote "$remote" --installed "$1" "${@:2}"; }

t_begin "newer tag"
assert_exit 0 run 0.7.0
assert_contains "$T_OUT" "BEARING_UPDATE: 0.7.0 -> 0.8.0"
t_end
t_begin "up to date"
rm -f "$cfg/bearing/update-check"
assert_exit 0 run 0.8.0
assert_eq "" "$T_OUT"
t_end
t_begin "offline prints nothing within budget"
rm -f "$cfg/bearing/update-check"; s=$(date +%s)
assert_exit 0 run 0.7.0 --remote "/nonexistent/x.git" --budget 3
assert_eq "" "$T_OUT"
assert_eq 1 "$([ $(( $(date +%s) - s )) -le 4 ] && echo 1 || echo 0)" "within budget"
t_end
t_begin "skipped version"
rm -f "$cfg/bearing/update-check"; mkdir -p "$cfg/bearing"; echo 'BEARING_UPDATE_SKIP=0.8.0' > "$cfg/bearing/bearing.env"
assert_exit 0 run 0.7.0
assert_eq "" "$T_OUT"
t_end
t_begin "snoozed"
echo "BEARING_UPDATE_SNOOZE_UNTIL=$(( $(date +%s) + 999 ))" > "$cfg/bearing/bearing.env"
assert_exit 0 run 0.7.0
assert_eq "" "$T_OUT"
t_end
t_begin "off"
: > "$cfg/bearing/bearing.env"
assert_exit 0 env BEARING_UPDATE_CHECK=off XDG_CONFIG_HOME="$cfg" bash "$U" --remote "$remote" --installed 0.7.0
assert_eq "" "$T_OUT"
t_end
t_summary
```

- [ ] **Step 2: Run to fail**

Run: `chmod +x tests/unit/update_check.sh && bash tests/unit/update_check.sh`
Expected: FAIL, script missing.

- [ ] **Step 3: Write `brg-update-check`**

```bash
#!/usr/bin/env bash
# brg-update-check: is a newer Bearing tag published? One git ls-remote at
# most once a day, inside a time budget; prints BEARING_UPDATE: <old> -> <new>
# or nothing. Never blocks a session and never prints on failure.
set -u
remote=""; installed=""; budget=3
while [ $# -gt 0 ]; do
  case "$1" in
    --remote) remote="${2:-}"; shift 2 || shift;;
    --installed) installed="${2:-}"; shift 2 || shift;;
    --budget) budget="${2:-3}"; shift 2 || shift;;
    *) shift;;
  esac
done
dir="${XDG_CONFIG_HOME:-$HOME/.config}/bearing"; envf="$dir/bearing.env"; cache="$dir/update-check"
setting() { local v; eval "v=\${$1:-}"; [ -n "$v" ] && { echo "$v"; return; }; [ -f "$envf" ] && grep -E "^$1=" "$envf" | tail -1 | cut -d= -f2-; }
[ "$(setting BEARING_UPDATE_CHECK)" = off ] && exit 0
here="$(cd "$(dirname "$0")" && pwd)"
[ -n "$installed" ] || installed="$(bash "$here/brg-guard" --version 2>/dev/null | awk '{print $2}')"
if [ -z "$remote" ] && command -v jq >/dev/null 2>&1; then
  remote="$(jq -r '.bearing.source.url // empty' "$HOME/.claude/plugins/known_marketplaces.json" 2>/dev/null)"
fi
[ -n "$installed" ] && [ -n "$remote" ] || exit 0
log_fail() { r="$(git rev-parse --show-toplevel 2>/dev/null)"; [ -n "$r" ] && [ -d "$r/.bearing/state" ] && printf '%s\tupdate-check\tnot-run\t0\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$1" >> "$r/.bearing/state/gates.log"; exit 0; }
vnum() { echo "$1" | sed 's/^v//' | awk -F. '{printf "%05d%05d%05d", $1, $2, $3}'; }
now="$(date +%s)"; newest=""
if [ -f "$cache" ]; then
  ts="$(cut -f1 "$cache")"; [ $(( now - ${ts:-0} )) -lt 86400 ] && newest="$(cut -f2 "$cache")"
fi
if [ -z "$newest" ]; then
  out="$(mktemp)"
  ( GIT_TERMINAL_PROMPT=0 git ls-remote --tags --refs "$remote" 'v*' > "$out" 2>/dev/null ) & pid=$!
  i=0; while kill -0 "$pid" 2>/dev/null; do [ "$i" -ge $((budget*10)) ] && { kill "$pid" 2>/dev/null; rm -f "$out"; log_fail timeout; }; sleep 0.1; i=$((i+1)); done
  wait "$pid" || { rm -f "$out"; log_fail ls-remote-failed; }
  newest="$(sed -n 's|.*refs/tags/\(v[0-9][0-9.]*\)$|\1|p' "$out" | while read -r t; do echo "$(vnum "$t") $t"; done | sort | tail -1 | awk '{print $2}')"
  rm -f "$out"; [ -n "$newest" ] || log_fail no-tags
  mkdir -p "$dir"; printf '%s\t%s\n' "$now" "$newest" > "$cache.tmp" && mv "$cache.tmp" "$cache"
fi
new="${newest#v}"
[ "$(vnum "$new")" \> "$(vnum "$installed")" ] || exit 0
[ "$(setting BEARING_UPDATE_SKIP)" = "$new" ] && exit 0
su="$(setting BEARING_UPDATE_SNOOZE_UNTIL)"; [ -n "$su" ] && [ "$now" -lt "$su" ] && exit 0
echo "BEARING_UPDATE: $installed -> $new"
cl="$here/../../../CHANGELOG.md"; [ -f "$cl" ] || cl="$here/../CHANGELOG.md"
if [ -f "$cl" ] && grep -q "^## .*$new" "$cl"; then awk -v v="$new" '$0 ~ "^## .*"v {p=1; next} p && /^## /{exit} p' "$cl" | grep . | head -8
else echo "See CHANGELOG.md at $remote"; fi
exit 0
```

- [ ] **Step 4: Wire it into `brg-guard session` (startup only)**

After the `echo "bearing session: ..."` line:

```bash
    if [ "$source" = "startup" ]; then
      up="$(bash "$(dirname "$0")/brg-update-check" --budget 3 2>/dev/null)"
      if [ -n "$up" ]; then
        old="$(printf '%s' "$up" | sed -n 's/^BEARING_UPDATE: \([^ ]*\) -> .*/\1/p')"; new="$(printf '%s' "$up" | sed -n 's/.* -> \(.*\)$/\1/p')"
        printf '%s\n' "$up"
        echo "Bearing $new is available (you have $old). Ask the user with AskUserQuestion: Upgrade now (run the upgrade-tools skill) / Remind me tomorrow (brg-config set update-snooze-until $(( $(date +%s) + 86400 )) --user) / Skip this version (brg-config set update-skip $new --user)."
      fi
    fi
```

- [ ] **Step 5: Run tests; confirm the session timeout holds**

Run: `bash tests/unit/update_check.sh && bash tests/unit/guard_session_stop.sh && bash tests/unit/guard_latency.sh`
Expected: `0 failed` each. The SessionStart hook's 10 s timeout covers the 3 s budget.

- [ ] **Step 6: Commit**

```bash
git add plugins/bearing/bin/brg-update-check plugins/bearing/bin/brg-guard tests/unit/update_check.sh
git commit -m "feat(update): offer a newer Bearing tag once a day with upgrade, snooze or skip"
```

---

### Task 18: Learning consent, local log and read back

**Files:**
- Create: `plugins/bearing/bin/brg-learn`
- Modify: `plugins/bearing/bin/brg-guard` (`session)` prints consent ask and top learnings; `stop-gate` and `check-file` blocks call `brg-learn log`)
- Test: `tests/unit/learn_local.sh` (create)

**Interfaces:**
- Produces: `brg-learn state` prints `on`, `off` or `ask`. `brg-learn log --kind <gate-block|rerun|override|manual> --skill <s> --key <k> --insight <text>` appends or increments (same kind+skill+key increments `count`) in `${XDG_CONFIG_HOME:-$HOME/.config}/bearing/learnings.jsonl`, only when state is `on`; paths in `--insight` reduced to their extension (`src/a/b.go` -> `*.go`). Entries carry no repository field at all (stricter than the spec's hashed name). Kinds come from: gate blocks (stop-gate, check-file), reruns (`brg-session timeline-start` sees the same skill start again in the same session within 600 s), overrides (console.md tells the model to log when the user picks a non-recommended option), and `learn add`. `brg-learn top --skills "<a b c>" [--n 5]` prints up to n `- <insight> (<count>x)` lines for those skills, by count then recency. Exit 0 always.
- Produces: `brg-guard session` on startup prints, when state is `ask`: `BEARING_LEARNING: ask. Ask the user once with AskUserQuestion: Yes, learn locally (brg-config set learning on --user) / No (brg-config set learning off --user). Nothing leaves this machine.` When `on`, prints `Learnings for the next step:` and `brg-learn top --skills "<next step>"`.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/learn_local.sh: consent states; nothing written unless on;
# counts increment; paths reduced; top ranks by count.
set -u
. "$(dirname "$0")/../lib/assert.sh"
L="$KIT/plugins/bearing/bin/brg-learn"
cfg="$(tmpdir)"; f="$cfg/bearing/learnings.jsonl"
run() { XDG_CONFIG_HOME="$cfg" bash "$L" "$@"; }
t_begin "unanswered is ask and writes nothing"
assert_exit 0 run state
assert_eq ask "$T_OUT"
assert_exit 0 run log --kind gate-block --skill go --key vet --insight "vet fails in src/a/b.go"
[ ! -e "$f" ]; assert_eq 0 $? "no file"
t_end
t_begin "off writes nothing"
mkdir -p "$cfg/bearing"; echo BEARING_LEARNING=off > "$cfg/bearing/bearing.env"
assert_exit 0 run log --kind manual --skill go --key x --insight y
[ ! -e "$f" ]; assert_eq 0 $? "no file"
t_end
t_begin "on logs, increments and reduces paths"
echo BEARING_LEARNING=on > "$cfg/bearing/bearing.env"
run log --kind gate-block --skill go --key vet --insight "vet fails in src/a/b.go" >/dev/null
run log --kind gate-block --skill go --key vet --insight "vet fails in src/a/b.go" >/dev/null
run log --kind manual --skill go --key other --insight "prefer table tests" >/dev/null
assert_eq 2 "$(wc -l < "$f" | tr -d ' ')" "two distinct entries"
assert_contains "$(cat "$f")" '"count":2'
assert_contains "$(cat "$f")" '*.go'
assert_not_contains "$(cat "$f")" 'src/a/b.go'
t_end
t_begin "top ranks by count"
assert_exit 0 run top --skills "go" --n 1
assert_eq "- vet fails in *.go (2x)" "$T_OUT"
t_end
t_summary
```

- [ ] **Step 2: Run to fail**

Run: `chmod +x tests/unit/learn_local.sh && bash tests/unit/learn_local.sh`
Expected: FAIL, script missing.

- [ ] **Step 3: Write `brg-learn` (local part; jq required for log and top, else no-op)**

```bash
#!/usr/bin/env bash
# brg-learn: opt-in, local learnings. Nothing leaves this machine; propose
# only drafts an issue body for the engineer to file.
#   state | log --kind K --skill S --key K --insight T | top --skills "a b" [--n N]
#   list | add "<text>" [--skill S] | propose [--out FILE]
set -u
sub="${1:-}"; shift || true
dir="${XDG_CONFIG_HOME:-$HOME/.config}/bearing"; envf="$dir/bearing.env"; f="$dir/learnings.jsonl"
kind=""; skill="general"; key=""; insight=""; skills=""; n=5; out=""; text=""
while [ $# -gt 0 ]; do
  case "$1" in
    --kind) kind="${2:-}"; shift 2 || shift;; --skill) skill="${2:-}"; shift 2 || shift;;
    --key) key="${2:-}"; shift 2 || shift;; --insight) insight="${2:-}"; shift 2 || shift;;
    --skills) skills="${2:-}"; shift 2 || shift;; --n) n="${2:-5}"; shift 2 || shift;;
    --out) out="${2:-}"; shift 2 || shift;; *) text="$1"; shift;;
  esac
done
state() { local v=""; [ -f "$envf" ] && v="$(grep -E '^BEARING_LEARNING=' "$envf" | tail -1 | cut -d= -f2-)"; case "$v" in on|off) echo "$v";; *) echo ask;; esac; }
reduce() { printf '%s' "$1" | sed -E 's#([A-Za-z0-9_.-]+/)+[A-Za-z0-9_-]+\.([A-Za-z0-9]+)#*.\2#g'; }
command -v jq >/dev/null 2>&1 || { [ "$sub" = state ] && state; exit 0; }
case "$sub" in
  state) state;;
  log|add)
    [ "$(state)" = on ] || exit 0
    [ "$sub" = add ] && { kind=manual; insight="$text"; key="$(printf '%s' "$text" | cksum | cut -d' ' -f1)"; }
    [ -n "$kind" ] && [ -n "$insight" ] || exit 0
    mkdir -p "$dir"; touch "$f"; ins="$(reduce "$insight")"; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    jq -c --arg k "$kind" --arg s "$skill" --arg y "${key:-$ins}" --arg i "$ins" --arg t "$ts" -s '
      (map(select(.kind==$k and .skill==$s and .key==$y)) | length) as $hit
      | if $hit > 0 then map(if .kind==$k and .skill==$s and .key==$y then .count += 1 | .ts = $t else . end)
        else . + [{ts:$t, kind:$k, skill:$s, key:$y, insight:$i, count:1}] end | .[]' "$f" > "$f.tmp" && mv "$f.tmp" "$f";;
  top)
    [ -f "$f" ] || exit 0
    jq -r -s --arg s " $skills " --argjson n "$n" '
      map(select(($s | contains(" " + .skill + " ")) or .skill == "general"))
      | sort_by(-.count, .ts) | .[:$n] | .[] | "- \(.insight) (\(.count)x)"' "$f";;
  list) [ -f "$f" ] && jq -r '"\(.count)x  \(.skill)  \(.insight)"' "$f";;
esac
exit 0
```

(`sort_by(-.count, .ts)` puts the highest count first; ties go to the older entry, which is acceptable and deterministic.)

- [ ] **Step 4: Wire into `brg-guard`**

In `session)` on `startup`, after the update block:

```bash
      lstate="$(bash "$(dirname "$0")/brg-learn" state)"
      if [ "$lstate" = ask ]; then
        echo "BEARING_LEARNING: ask. Ask the user once with AskUserQuestion: Yes, learn locally (brg-config set learning on --user) / No (brg-config set learning off --user). Nothing leaves this machine."
      elif [ "$lstate" = on ]; then
        nx="$(bash "$(dirname "$0")/brg-session" next-step 2>/dev/null)"
        tops="$(bash "$(dirname "$0")/brg-learn" top --skills "$nx" --n 5)"
        [ -z "$tops" ] || { echo "Learnings for the next step:"; printf '%s\n' "$tops"; }
      fi
```

In `stop-gate)` right before `exit 2;;`: `bash "$(dirname "$0")/brg-learn" log --kind gate-block --skill stop-gate --key "$target" --insight "stop gate blocked; ${target} needed" >/dev/null 2>&1`.
In `brg-session timeline-start`, before `event "$skill" start`, add rerun detection (uses the `epoch` field Task 12 writes on every event):

```bash
    last="$(grep "\"session\":\"$(esc "$id")\"" "$tl" 2>/dev/null | grep '"event":"start"' | tail -1)"
    if printf '%s' "$last" | grep -q "\"skill\":\"$(esc "$skill")\""; then
      le="$(printf '%s' "$last" | sed -n 's/.*"epoch":\([0-9]*\).*/\1/p')"
      if [ -n "$le" ] && [ $(( $(date +%s) - le )) -le 600 ]; then
        bash "$(dirname "$0")/brg-learn" log --kind rerun --skill "$skill" --key rerun --insight "$skill rerun within ten minutes in one session" >/dev/null 2>&1
      fi
    fi
```

In `plugins/bearing/references/console.md` step 4, append: `When the user picks an option other than the recommended one and learning is on, run bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-learn" log --kind override --skill <skill> --key <question id> --insight "<question>: chose <option> over <recommended>".`

In `check-file)` where it logs `problems`: `bash "$(dirname "$0")/brg-learn" log --kind gate-block --skill check-file --key "${file##*.}" --insight "check-file problems on *.${file##*.} via $tool" >/dev/null 2>&1`.

- [ ] **Step 5: Run tests**

Run: `bash tests/unit/learn_local.sh && bash tests/unit/guard_session_stop.sh && bash tests/unit/changed_files.sh && bash tests/unit/guard_latency.sh`
Expected: `0 failed` each.

- [ ] **Step 6: Commit**

```bash
git add plugins/bearing/bin/brg-learn plugins/bearing/bin/brg-guard tests/unit/learn_local.sh
git commit -m "feat(learn): opt-in local learnings from gate blocks, read back for the next step"
```

---

### Task 19: The `learn` skill and the redacted upstream proposal

**Files:**
- Create: `plugins/bearing/skills/learn/SKILL.md`, `evals/learn/evals.json`
- Modify: `plugins/bearing/bin/brg-learn` (`propose`), `docs/flows.json` only if the handbook lists maintenance skills (check `grep -n upgrade-tools docs/flows.json`; add `learn` beside it if so)
- Test: `tests/unit/learn_propose.sh` (create)

**Interfaces:**
- Produces: `brg-learn propose [--out FILE]` writes a Markdown issue body grouping entries with `count >= 3` by skill, runs redaction, and exits 1 with `learn propose: redaction failed: <n> suspect token(s)` listing them if any line still matches a path with a slash, an email, a hostname with a dot and a TLD, or a token of 20 or more `[A-Za-z0-9_-]` characters; on success prints `learn propose: <n> learnings, written to <FILE>` and the command `gh issue create --repo Deepta-AI/bearing --title "Learnings from Bearing use" --body-file <FILE>` for the engineer to run. Default FILE `.scratch/learn-proposal.md`. Zero eligible entries: exit 1 with `learn propose: 0 learnings seen 3 or more times, nothing to propose`.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/learn_propose.sh: propose writes a body, prints the gh command,
# fails on zero entries and on anything that looks identifying.
set -u
. "$(dirname "$0")/../lib/assert.sh"
L="$KIT/plugins/bearing/bin/brg-learn"
cfg="$(tmpdir)"; mkdir -p "$cfg/bearing"; f="$cfg/bearing/learnings.jsonl"; o="$(tmpdir)/p.md"
run() { XDG_CONFIG_HOME="$cfg" bash "$L" "$@"; }
t_begin "zero eligible"
: > "$f"
assert_exit 1 run propose --out "$o"
assert_contains "$T_OUT" "0 learnings seen 3 or more times"
t_end
t_begin "clean proposal"
printf '%s\n' '{"ts":"t","kind":"gate-block","skill":"go","key":"vet","insight":"vet fails in *.go","count":4}' > "$f"
assert_exit 0 run propose --out "$o"
assert_contains "$T_OUT" "gh issue create --repo Deepta-AI/bearing"
assert_contains "$(cat "$o")" "vet fails in *.go"
t_end
for bad in "see src/app/main.go" "mail a@b.example" "host api.client.example.com" "token AbCdEfGhIjKlMnOpQrStUv"; do
  t_begin "redaction: $bad"
  printf '{"ts":"t","kind":"manual","skill":"go","key":"k","insight":"%s","count":3}\n' "$bad" > "$f"
  assert_exit 1 run propose --out "$o"
  assert_contains "$T_OUT" "redaction failed"
  t_end
done
t_summary
```

- [ ] **Step 2: Run to fail**

Run: `chmod +x tests/unit/learn_propose.sh && bash tests/unit/learn_propose.sh`
Expected: FAIL.

- [ ] **Step 3: Implement `propose` in `brg-learn` (before `esac`)**

```bash
  propose)
    out="${out:-.scratch/learn-proposal.md}"
    [ -f "$f" ] && rows="$(jq -c 'select(.count >= 3)' "$f")" || rows=""
    m="$(printf '%s' "$rows" | grep -c . || true)"
    [ "$m" -gt 0 ] || { echo "learn propose: 0 learnings seen 3 or more times, nothing to propose"; exit 1; }
    body="$(printf '%s\n' "$rows" | jq -r -s 'group_by(.skill) | .[] |
      "## \(.[0].skill)\n" + (map("- \(.insight) (seen \(.count) times, \(.kind))") | join("\n")) + "\n"')"
    sus="$(printf '%s\n' "$body" | grep -oE '[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+|[^ @]+@[^ @]+\.[a-z]{2,}|([a-z0-9-]+\.)+[a-z]{2,}|[A-Za-z0-9_-]{20,}' | grep -v '^\*\.' || true)"
    if [ -n "$sus" ]; then
      echo "learn propose: redaction failed: $(printf '%s\n' "$sus" | wc -l | tr -d ' ') suspect token(s)"; printf '%s\n' "$sus" | sed 's/^/  /'; exit 1
    fi
    mkdir -p "$(dirname "$out")"
    { echo "Learnings from Bearing use, generated by brg-learn propose. Only entries seen 3 or more times; paths reduced to extensions."; echo; printf '%s\n' "$body"; } > "$out"
    echo "learn propose: $m learnings, written to $out"
    echo "Review it, then run: gh issue create --repo Deepta-AI/bearing --title \"Learnings from Bearing use\" --body-file $out";;
```

(The `*.go` style tokens are excluded from the path check by `grep -v '^\*\.'`; `*.go` itself does not match the slash pattern.)

- [ ] **Step 4: Write the skill**

`plugins/bearing/skills/learn/SKILL.md`:

```markdown
---
name: learn
description: 'Lists, adds and proposes Bearing learnings from this machine (opt-in, local). Use when asked "what has Bearing learned", "remember this for next time" or "send our learnings upstream".'
allowed-tools: AskUserQuestion, Bash(bash *bin/brg-learn*), Bash(bash *bin/brg-config*), Read
---

# learn

Bearing learns only with consent, only on this machine. This skill is the
way in and the way out. Questions follow
`${CLAUDE_PLUGIN_ROOT}/references/console.md`.

## Steps

1. State: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-learn" state`. `ask`: ask
   once with AskUserQuestion (Yes, learn locally / No; nothing leaves this
   machine) and record with `brg-config set learning on|off --user`. `off`:
   say so and stop unless the user asked to turn it on.
2. `learn` alone: `brg-learn list`, newest and most frequent first.
3. `learn add "<text>"`: `brg-learn add "<text>" --skill <skill if named>`.
4. `learn propose`: `brg-learn propose`. On redaction failure show the
   suspect tokens and stop; never edit the file to pass. On success show
   the file and print the `gh issue create` line for the engineer. Never
   run it.

## Output contract

```
Learning: <on|off|ask>
<the list | "added" | the proposal path and the gh command>
```

## Gotchas

- The log holds no code, prompts or paths; a proposal that fails redaction
  means an insight was written with a real name in it. Fix the entry with
  the user, do not weaken the check.
```

`evals/learn/evals.json`: copy the shape of `evals/upgrade-tools/evals.json` with two should-trigger prompts (`"what has bearing learned so far"`, `"remember that our go repos use table tests"`) and two should-not (`"learn how to use react hooks"`, `"teach me kubernetes"`).

- [ ] **Step 5: Run tests and skill lints**

Run: `bash tests/unit/learn_propose.sh && make lint-skills lint-tools lint-evals lint-triggers lint-skill-size && make docs`
Expected: `0 failed`; lints 0 problems; `make docs` regenerates SKILLS.md.

- [ ] **Step 6: Commit**

```bash
git add plugins/bearing/bin/brg-learn plugins/bearing/skills/learn evals/learn tests/unit/learn_propose.sh docs site devguide
git commit -m "feat(learn): the learn skill; propose drafts a redacted issue for the engineer to file"
```

---

### Task 20: Context-aware menu in `workflow`

**Files:**
- Modify: `plugins/bearing/skills/workflow/SKILL.md`
- Test: `evals/workflow/evals.json` (add one case)

**Interfaces:**
- Consumes: `brg-session resume`, `brg-session timeline-recent`, `brg-learn top`.

- [ ] **Step 1: Add the eval case first**

Add to `evals/workflow/evals.json` a case with prompt `"/workflow"` (no argument) and expectations: output's first lines name two or three skills each with a one-line reason; contains the full stage table after them; runs no skill. Follow the file's existing case shape exactly.

- [ ] **Step 2: Run to see the case is new**

Run: `make lint-evals`
Expected: passes and its count rises by one.

- [ ] **Step 3: Edit the skill**

Add `Bash(bash *bin/brg-session*)`, `Bash(bash *bin/brg-learn*)` and `AskUserQuestion` to `allowed-tools`. Insert after the first paragraph:

```markdown
## With no argument: the menu

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-session" resume` and read the
   checkpoint, the last skills and the next flow step.
2. Lead with the two or three best next skills, each with one line of
   reason taken from that output or the repository (uncommitted files with
   no check: `definition-of-done`; next flow step: that skill; a stale
   progress record: `session-handoff`).
3. Then the stage table below.
4. Ask with AskUserQuestion which to run (the first is the recommendation).
   Never run one without an answer. Questions follow
   `${CLAUDE_PLUGIN_ROOT}/references/console.md`.
```

- [ ] **Step 4: Gates**

Run: `make lint-skills lint-tools lint-evals lint-skill-size && bash tests/unit/skill_evals.sh && make docs`
Expected: 0 problems; `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/skills/workflow evals/workflow docs site devguide
git commit -m "feat(workflow): with no argument, lead with the next two or three skills and ask"
```

---

### Task 21: `lint-questions` and converting the 27 prose askers

**Files:**
- Modify: `Makefile` (target, joins `check`)
- Modify: the 27 SKILL.md files listed by Step 3
- Test: `tests/unit/lint_questions.sh` (create)

**Interfaces:**
- Produces: `make lint-questions` prints `lint-questions: <N> skills, <Q> ask the user, 0 in prose` or lists each SKILL.md whose body matches `ask the user|ask once|ask:` (case-insensitive) without both `AskUserQuestion` in `allowed-tools` and the string `references/console.md`; 0 skills exits 1.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/lint_questions.sh: a skill that asks in prose fails; one that
# uses AskUserQuestion and cites console.md passes; zero skills fails.
set -u
. "$(dirname "$0")/../lib/assert.sh"
w="$(tmpdir)"; mkdir -p "$w/plugins/p/skills/a"; cp "$KIT/Makefile" "$w/Makefile"
printf -- '---\nname: a\nallowed-tools: Read\n---\nIf absent, ask the user once.\n' > "$w/plugins/p/skills/a/SKILL.md"
t_begin "prose fails"
assert_exit 2 make -s -C "$w" lint-questions
assert_contains "$T_OUT" "plugins/p/skills/a/SKILL.md"
t_end
t_begin "tool and contract pass"
printf -- '---\nname: a\nallowed-tools: Read, AskUserQuestion\n---\nIf absent, ask the user once (references/console.md).\n' > "$w/plugins/p/skills/a/SKILL.md"
assert_exit 0 make -s -C "$w" lint-questions
assert_contains "$T_OUT" "lint-questions: 1 skills, 1 ask the user, 0 in prose"
t_end
t_begin "zero skills"
rm -rf "$w/plugins/p/skills/a"
assert_exit 2 make -s -C "$w" lint-questions
t_end
t_summary
```

- [ ] **Step 2: Add the target and run**

```make
lint-questions: ## A skill that asks the user does it with AskUserQuestion and follows references/console.md
	@n=0; q=0; bad=0; \
	for f in plugins/*/skills/*/SKILL.md; do [ -f "$$f" ] || continue; n=$$((n+1)); \
	  grep -qiE 'ask the user|ask once|ask:' "$$f" || continue; q=$$((q+1)); \
	  if ! sed -n '/^---$$/,/^---$$/p' "$$f" | grep -q 'AskUserQuestion' || ! grep -q 'references/console.md' "$$f"; then echo "asks in prose: $$f"; bad=$$((bad+1)); fi; done; \
	[ "$$n" -gt 0 ] || { echo "lint-questions: 0 skills, nothing checked" >&2; exit 1; }; \
	[ "$$bad" -eq 0 ] || { echo "lint-questions: $$bad of $$q skills ask in prose"; exit 1; }; \
	echo "lint-questions: $$n skills, $$q ask the user, 0 in prose"
```

Run: `chmod +x tests/unit/lint_questions.sh && bash tests/unit/lint_questions.sh && make -s lint-questions | tail -1`
Expected: test `0 failed`; the real run lists the prose askers and ends `lint-questions: <k> of <q> skills ask in prose` (k about 27; `prd`, `start-task`, `learn`, `workflow` already pass).

- [ ] **Step 3: Convert each listed skill (one commit per three to five skills)**

For each file the lint lists: add `AskUserQuestion` to `allowed-tools`; rewrite each "ask the user" / "ask once" sentence as "ask with AskUserQuestion (two to four options, recommended first) as `${CLAUDE_PLUGIN_ROOT}/references/console.md` says; record the answer with `brg-config set <key>` when it is a project fact"; add `Bash(bash *bin/brg-config*)` to `allowed-tools` when the step records. Keep the skill at 200 lines or fewer.
After each batch: `make lint-skills lint-tools lint-skill-size && bash tests/unit/trigger_eval.sh`, expected 0 problems and `0 failed`, then
`git commit -m "feat(<skills>): ask with AskUserQuestion under the console contract"`.

- [ ] **Step 4: Join the gate**

Add `lint-questions` to `check:` after `lint-skill-size`.
Run: `make -s lint-questions && make check 2>&1 | tail -2`
Expected: `lint-questions: 107 skills, <q> ask the user, 0 in prose` (107 with `learn`); `check: passed`.

- [ ] **Step 5: Commit**

```bash
git add Makefile tests/unit/lint_questions.sh
git commit -m "build: lint-questions joins make check"
```

---

### Task 22: Speed acceptance, version 0.8.0, CHANGELOG

**Files:**
- Modify: `VERSION`, every `plugins/*/.claude-plugin/plugin.json` version, `CHANGELOG.md`, generated docs
- Create: `.scratch/speed-acceptance.md` (not committed; its numbers go into the MR)

- [ ] **Step 1: Speed acceptance (spec "Testing and gates")**

On a scaffolded Go service and a scaffolded Next.js app, each with the 0.7.0 plugin and then this branch (`claude --plugin-dir plugins/bearing`): run the same scripted bugfix prompt headless (`claude -p "Fix: /health returns 500 when the DB is down; add a test." --permission-mode acceptEdits`), then `bash plugins/bearing/bin/brg-guard stats` in the repo.
Record per run: number of `stop-gate blocked` lines naming `make check` before `definition-of-done`; Stop-gate check duration median (from `gates.log`: the time between `stop-gate blocked` and the next `stop-gate passed`); every hook step median.
Expected on this branch: 0 full `make check` before definition-of-done; Stop-gate check median at least 50% below the full `make check` time on that repository; no hook step median over 200 ms except `check-changed`. If a toolchain is missing, write "not run: <tool> missing" for that stack. Do not round or estimate numbers.

- [ ] **Step 2: Version and changelog**

Set `VERSION` to `0.8.0` and every plugin's `plugin.json` `"version"` to `0.8.0`. Add to `CHANGELOG.md` a `## 0.8.0` section listing: scoped Stop gate (`check-changed` in 13 templates; full `make check` unchanged at definition-of-done and pre-push), timing in `doctor --timing`, Sonnet review agents with Opus by severity, skills at 200 lines or fewer, workspace trust check, skill timeline and checkpoints, resume with next step, SessionEnd progress, update prompt, opt-in local learning and the `learn` skill, `console.md` and `brg-config`, `workflow` menu, `lint-skill-size` and `lint-questions`. Note for existing repositories: add `check-changed` by copying it from the stack template or running `onboard-repo`; until then the Stop gate behaves as in 0.7.0.

- [ ] **Step 3: Full gate**

Run: `make docs && make check 2>&1 | tail -3`
Expected: `check: passed`. Then `make lint-version` passes with 0.8.0.

- [ ] **Step 4: Commit**

```bash
git add VERSION plugins/*/.claude-plugin/plugin.json CHANGELOG.md docs site devguide
git commit -m "chore(release): 0.8.0 notes and version"
```

- [ ] **Step 5: Hand over (Bearing never pushes)**

Run `definition-of-done`, then `merge-request` to draft the MR body with Changed, Verified (each lint and test count line, the speed table), Not done, Noticed. Print for the engineer: `make gate && git push -u origin feat/RuntimeAndFeel`.
