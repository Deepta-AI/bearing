---
name: prose-lint
description: 'Lints prose people read (docs, MR text, commits, UI copy) for em dashes, AI filler and self-praise, rewriting whole sentences. Use when asked to "check the prose", "lint the README" or "does this sound AI-written".'
argument-hint: "[file or directory, default: changed .md files and UI strings]"
allowed-tools: Read, Edit, Grep, Glob, Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(make check:*), Bash(python3 *skills/prose-lint/scripts/prose_check.py*)
---

# prose-lint

Prose that sounds generated gets skimmed. This skill finds the tells and
rewrites the sentence, never just the character. The harder half of the
job is that generated prose is usually also wrong: it states guarantees
the code does not give, counts nobody counted and platforms nobody ran.
A cleanup that makes a false sentence read confidently has made the
document worse, so every factual sentence is checked against the
repository before it is kept, and every sentence the rewrite adds is
checked the same way.

What it covers: em dashes; AI-sounding filler; self-reference and
praise; attribution trailers; hedged or unverified claims; layout tells
(headers in short text, bullets that are paragraphs, one-word bold
labels in running prose); and the facts those sentences carry.

## Inputs

- Scope: `$ARGUMENTS` (a file, a directory, or pasted text); if absent,
  the prose the request points at ("the docs I added" means the prose
  files the branch changed: `git diff --name-only <base>...HEAD`, plus
  uncommitted ones from `git status`); if not a git repository or nothing
  has changed, every `.md` and UI string file under the current
  directory. Zero files after all three: stop with "provide a file, a
  directory or the text". Files the branch did not touch are out of
  scope even when they carry the same tells: name them, do not edit them.
- Base branch: `main`, else `master`, else the upstream's default.
- Finder: `scripts/prose_check.py` in this skill, Python 3 only. It
  finds and counts the greppable tells; the rewriting, the layout tells
  and the fact check stay with the skill.

## Steps

1. Resolve the scope and print the file count. Pasted text is linted in
   the reply and returned rewritten.
2. Run the finder from the repository root and keep its output:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/prose-lint/scripts/prose_check.py" <files or directory>`,
   or `git diff --name-only <base>...HEAD | python3 "${CLAUDE_PLUGIN_ROOT}/skills/prose-lint/scripts/prose_check.py" --files-from -`,
   and for the branch's commit messages
   `git log --format=%B <base>..HEAD | python3 "${CLAUDE_PLUGIN_ROOT}/skills/prose-lint/scripts/prose_check.py" --text -`.
   It prints `problem: file:line: class: match` per hit, a `left:` line
   per word that is also a string literal in the source (confirm it; see
   Literal values), and a `prose-lint:` counts line. It exits 1 on any
   hit or on zero files read. What it finds:
   - Em dashes (U+2014) in prose. Not in fenced code, inline code or
     quoted program output: those are counted as left, because a doc
     that quotes output must match what the program prints.
   - Filler: delve, leverage, robust, seamless, comprehensive, streamline,
     "it's worth noting", "in today's fast-paced", "I hope this helps",
     "great question", certainly.
   - Praise and self-reference: "as requested", "as you asked", "I have
     successfully", "great job", excellent.
   - Attribution trailers: `Co-Authored-By:` naming an AI assistant,
     "Generated with", the robot emoji.
   - Hedges: "should work", "this ensures". These mark a claim to check
     (step 3), not a word to swap.
3. Check every factual sentence in scope, not only the ones the finder
   hit. For each claim about behaviour, a number, a guarantee, a platform
   or a result, find the line that makes it true: the code path, the test
   that asserts it, the CI job that runs it, or the diff that counts it.
   Classify it:
   - supported: keep the fact, reword the tells;
   - contradicted: rewrite it to what the code does, and list it for the
     user (they may have meant the doc as the spec and the code is the
     bug; say so, do not change the code);
   - unverified (no test, no CI job, not run here): say it was not
     tested, or drop it. Never harden "should work" into "works".
   The traps a generalist lets through, each seen in real drafts:
   - Durability words. `flush()` hands bytes to the OS; only `fsync`
     reaches the disk, so "flushed to disk" is wrong without it. Nothing
     short of write-to-temp-then-rename is atomic, so "always consistent",
     "never corrupt" and "holds only complete batches" are false for a
     file written in place: a crash leaves a partial file whose last
     batch may be cut mid-row (buffered writes reach the file before the
     flush).
   - Resume and idempotence. Mode `"w"` truncates, so a rerun starts
     over; "picks up where it left off" needs code that reads the
     previous output or a checkpoint. Find it or remove the claim.
   - Memory and passes. `list(reader)`, `readlines()`, `read()`,
     `json.load` or `io.ReadAll` hold the whole input: "streams", "one
     pass" with constant memory, and "never runs out of memory" are false,
     and writing in batches does not change that.
   - Counts in MR text. Compute them, do not copy them: new tests are the
     test functions added in `git diff <base>...HEAD` (count `^+def test_`,
     `^+func Test`, `^+\s*(it|test)\(` per file); totals come from the
     tree or a test run you did. Say which you did.
   - Platforms and checks. "Tested on", "works on", "CI passes" need the
     CI file's job and image, or a run in this session. A Linux-only CI
     means other platforms are untested, whatever the stdlib-only argument.
   - Defaults and values. Option defaults, batch sizes and allowed values
     come from the argument parser and constants, not from the old doc.
   After rewriting, run the same check on every sentence you wrote. A
   replacement guarantee is the usual failure: the fix for "always
   consistent" is "a crash can leave a partial file", not another
   promise.
4. Rewrite each hit in place, one sentence at a time. Em dash by what
   follows it: a conjunction or relative pronoun takes a comma; an
   independent clause takes a full stop; a verbless appositive takes a
   comma; a label-to-value pair takes a colon; a matched pair becomes
   brackets or its own sentence. Replace filler with the concrete thing
   (not with a synonym: robust to powerful is the same tell). Keep the
   facts the sentence carried when they are true; never just delete the
   character.
5. Rerun the finder on the same scope and list what was left and why.
   Run the repository's check (`make check` or its equivalent) when docs
   quote output that tests assert, and report the count it printed.
6. Committed commit messages are not edited (no amend, rebase or reset):
   list each one that carries a tell or a trailer, since they show in the
   MR's commit list, and print the reword command for the engineer.
   Nothing is committed or staged by this skill.

## Literal values

A flagged word can be data: "excellent" as a rating, "robust" as a mode
name, "certainly" inside a quoted user message. The finder prints a
`left: ... literal` line when the word is also a string literal in the
source and names where. Confirm it against that line, keep it, and keep
the full list it belongs to in the same order; never rename or drop a
value to make the lint pass. A word the finder did not recognise as a
literal is still checked by reading the sentence: praise addresses the
reader or the work, a value is something the program accepts or prints.

## Gotchas

- Code, identifiers and strings the program prints. A doc quoting
  `0 rows matched` plus an em dash must keep the dash when the program
  prints it; changing the program string is a code change, so name it
  and leave it.
- A table cell holding only a dash for "no value" is typography; keep it
  or replace it with an explicit word (none, unset, not checked), never
  leave the cell empty or drop a column.
- Files outside the scope, even with the same tells.

## Output contract

```
## Prose lint: <scope> (<N> files)
| File | Hits | Fixed | Left (reason) |
Before: <prose-lint: counts line from step 2>
After: <prose-lint: counts line from step 5>
Claims changed: <file: old claim -> what the code does, with file:line> | none
Unverified, now stated as untested: <claim> | none
Commits: <message and its tells, reword left to the engineer> | none | skipped (no repository)
Checks run: <command and the count it printed> | not run
```

A count the script or a check did not print is not written.
