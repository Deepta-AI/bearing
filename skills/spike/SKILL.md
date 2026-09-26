---
name: spike
description: 'Runs a timeboxed spike: a yes, no or number question, a timebox and stop condition, throwaway code never merged, a written recommendation. Use when asked to "spike this", "investigate whether" or "prototype to find out".'
argument-hint: "<name> \"<question>\" [--hours 4] [--branch]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(date:*), Bash(printenv:*), Bash(git status:*), Bash(git branch:*), Bash(git switch -c:*), Bash(git log:*), Bash(git diff:*), Bash(go run:*), Bash(go test:*), Bash(node:*), Bash(pnpm exec:*), Bash(uv run:*), Bash(python3:*)
---

# spike

A spike buys an answer with a fixed amount of time. The question is
written before the code, the clock is checked at every finding, and the
only thing that survives is the document.

Not this: `systematic-debugging` for a bug with a symptom;
`tech-decision` for a choice the options already answer.

## Inputs

- name: `$1`, kebab-case; if absent, ask once.
- question: `$2`; if absent, ask once. A question whose answer is not
  yes, no or a number is rewritten with the user until it is ("can X
  serve 500 rps on one pod?" rather than "look into X").
- timebox: `--hours`, default 4. Start written as `date -u +%FT%TZ`.
- location: `.scratch/spike-<name>/` (created); `--branch` creates
  `spike/<name>` with `git switch -c` from the current branch instead.
  Not a git repository: `.scratch/` only.
- state: `.bearing/state/spike-<name>.md` (created with `mkdir -p`); holds
  question, start, timebox, stop condition and every finding as it lands.
- prior spikes: `docs/spikes/*.md` grepped for the name and the subject
  nouns; a prior answer is printed before anything starts.
- tracker: `printenv BEARING_TRACKER`, else the `BEARING_TRACKER` line in
  `~/.config/bearing/bearing.env`; `none` or unset: the follow-up is a
  line in the doc with the note `tracker: none`; otherwise the
  `tracker-sync create` command is printed, never run here.
- template in this skill: `templates/spike.md`.

## Steps

1. Resolve name, question and timebox. Grep prior spikes; print "K prior
   spikes on this subject" and their answers. Write the state file.
   Create the location; with `--branch` print "never merge spike/<name>".
2. Before any code, write into the state file: "answered looks like"
   (the number and its threshold, or the artefact that must exist: a
   passing call, a rendered screen, a build that links) and the stop
   condition (answer reached, timebox over, or a blocker outside the
   question). Confirm both in one question.
3. Investigate inside the location only. The smallest code that answers
   the question; no tests beyond the measurement; no production file
   touched. `git status --porcelain` outside the location (or off the
   spike branch) showing a change is a finding: revert it before going
   on. Each finding goes into the state file with a UTC time and its
   evidence (the command and its output line, the number, a path).
4. Check the clock at every finding: elapsed against the timebox. At 50
   percent with no finding, say so and ask once: continue or stop. At
   100 percent, stop whatever the state.
5. Write `docs/spikes/<date>-<name>.md` from `templates/spike.md`:
   question, answer (yes, no, the number, or "not answered: <why>"),
   findings with evidence, what was tried and discarded, where it was
   measured, recommendation (adopt, reject, or a narrower spike with its
   question written), the follow-up task title with the `tracker-sync
   create --type task --title "<title>"` command or `tracker: none`, and
   the throwaway note. Zero findings is a valid result; it is written
   as not answered with the reason.
6. Print the contract, including `git branch -D spike/<name>` for the
   engineer to run after the doc is committed. `.scratch/` needs nothing.

## Output contract

```
## Spike: <name>
Question: <one line>
Timebox: <h> h, used <h> h (<start> to <end> UTC)   Stopped: answered | timebox | blocker
Answer: yes | no | <number and unit> | not answered (<why>)
Findings: N (each with evidence)   Prior spikes: K
Measured on: <laptop | staging | prod-like>
Recommendation: adopt | reject | narrower spike ("<question>")
Follow-up: "<title>" (tracker-sync create --type task ... | tracker: none)
Throwaway: .scratch/spike-<name>/ | spike/<name> (engineer: git branch -D spike/<name>)
Path: docs/spikes/<date>-<name>.md
```

## Gotchas

- A spike that ships its code is a feature without tests. The code is
  thrown away; the doc and the follow-up are what survive.
- "Look into X" is not a question. When the answer cannot be yes, no
  or a number, the spike cannot end.
- The timebox is the point. "One more hour" is how a spike becomes a
  week; the 50 percent check exists to catch that.
- A spike that answers a different question is recorded as "not
  answered" for the question asked, with what was learnt beneath.
- Laptop numbers are not production numbers; the doc names where it
  was measured.
- Two spikes on one subject mean the first question was too wide; the
  second is written narrower and links the first.
- The state file is under `.bearing/state/`; the spike code is under
  `.scratch/`; neither is committed. Only `docs/spikes/` is.
