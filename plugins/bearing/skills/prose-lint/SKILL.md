---
name: prose-lint
description: 'Lints prose people read (docs, MR text, commits, UI copy) for em dashes, AI filler and self-praise, rewriting whole sentences. Use when asked to "check the prose", "lint the README" or "does this sound AI-written".'
argument-hint: "[file or directory, default: changed .md files and UI strings]"
allowed-tools: Read, Edit, Grep, Glob, Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(python3 *skills/prose-lint/scripts/prose_check.py*)
---

# prose-lint

Prose that sounds generated gets skimmed. This skill finds the tells and
rewrites the sentence, never just the character.

What it covers: em dashes; AI-sounding filler; self-reference and
praise; attribution trailers; hedged claims about verification; layout
tells (headers in short text, bullets that are paragraphs, one-word
bold labels in running prose).

## Inputs

- Scope: `$ARGUMENTS` (a file, a directory, or pasted text); if absent,
  the changed `.md`, `.txt`, `.xcstrings`, `strings.xml` and UI string
  files from `git status`; if not a git repository or nothing has changed,
  every `.md` and UI string file under the current directory. Zero files
  after all three: stop with "provide a file, a directory or the text".
- Pattern list: the list below; no repository configuration needed. A
  `.prose-lint-ignore` file, when present, adds allowed words one per line.
- Commit messages: `git log` on the branch when a repository exists;
  otherwise skipped and said so.
- Finder: `scripts/prose_check.py` in this skill, Python 3 only. It
  finds and counts the greppable patterns below; the rewriting and the
  layout tells stay with the skill.

## Steps

1. Resolve the scope as in Inputs and print the file count. Pasted text is
   linted in the reply and returned rewritten.
2. Run the finder over the scope and print its lines before editing:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/prose-lint/scripts/prose_check.py" <file or directory>`,
   or for the changed files
   `git diff --name-only HEAD | python3 "${CLAUDE_PLUGIN_ROOT}/skills/prose-lint/scripts/prose_check.py" --files-from -`,
   and for the branch's commit messages
   `git log --format=%B <base>..HEAD | python3 "${CLAUDE_PLUGIN_ROOT}/skills/prose-lint/scripts/prose_check.py" --text -`.
   It prints `problem: file:line: class: match` per hit and a
   `prose-lint:` counts line, and exits 1 on any hit or on zero files
   read. The patterns it finds (the layout tells in the last bullet are
   read, not found by the script):
   - Em dashes (U+2014, `grep -rnP '\xE2\x80\x94'`) anywhere. Rewrite
     by what follows the dash: a conjunction or relative pronoun takes a
     comma; an independent clause takes a full stop; a verbless
     appositive takes a comma; a label-to-value pair takes a colon; a
     matched pair becomes brackets.
   - AI-sounding filler: "delve", "leverage", "robust", "seamless",
     "comprehensive", "streamline", "it's worth noting", "in today's
     fast-paced", "I hope this helps", "great question", "certainly".
   - Self-reference and praise: "as requested", "as you asked", "I have
     successfully", "great job", "excellent".
   - Attribution trailers: `Co-Authored-By:` naming an AI assistant,
     "Generated with", the robot emoji.
   - Hedged claims about verification: "should work", "this ensures"
     where no check was run.
   - Headers in short text, bullets that are paragraphs, one-word bold
     labels followed by colons in running prose.
3. Rewrite each hit in place, one sentence at a time, keeping meaning.
   Never just delete the character.
4. Rerun the finder on the same scope. Print its counts line from both
   runs (the first gives the hits, the second what is left), and list
   what was left and why, for example a literal table-cell dash used as
   "no value", which the finder already counts as left.

## Output contract

```
## Prose lint: <scope> (<N> files)
| File | Hits | Fixed | Left (reason) |
...
Before: <prose_check.py "prose-lint:" counts line from step 2, verbatim>
After: <prose_check.py "prose-lint:" counts line from step 4, verbatim>
Commits: <prose_check.py --text counts line> (messages to reword listed, not edited) | skipped (no repository)
```

A count the script did not print is not written.

## Gotchas

- A bare em dash as a table-cell filler for "no value" is typography,
  not prose; leave it and say so.
- Commit messages already committed are not edited (no history rewrite);
  report them for the engineer.
- Code and identifiers are out of scope. Comments are in scope.
