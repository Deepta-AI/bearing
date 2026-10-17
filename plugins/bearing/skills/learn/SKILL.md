---
name: learn
description: 'Lists, adds and proposes Bearing learnings kept on this machine (opt-in). Use when asked "what has Bearing learned", "remember this for next time" or "send our learnings upstream".'
argument-hint: "[add <text> | propose]"
allowed-tools: AskUserQuestion, Read, Bash(bash *bin/brg-learn*), Bash(bash *bin/brg-config*)
---

# learn

Bearing learns only with consent and only on this machine. This skill is
the way in and the way out. Questions follow
`${CLAUDE_PLUGIN_ROOT}/references/console.md`.

## Inputs

- `$1`: absent (list), `add` with the text, or `propose`.
- The consent state from `brg-learn state`; nothing else is read.

## Steps

1. State: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-learn" state`.
   - `ask`: ask once with AskUserQuestion. Consent is the user's call,
     so recommend no option and say so. Options: "Yes, learn locally"
     (recurring gate blocks and notes are kept in a file on this machine
     and shown in later steps) and "No" (nothing is kept; you can turn it
     on later). Record the answer with
     `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-config" set learning on --user`
     (or `off`).
   - `off`: say so and stop, unless the user asked to turn it on.
2. No argument: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-learn" list`. Show it
   most frequent first, then newest, with the count of entries.
3. `add <text>`: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-learn" add "<text>" --skill <skill, if the user named one>`.
   The text goes in as the user wrote it, minus anything that names a
   file, host, person or ticket.
4. `propose`: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-learn" propose`.
   - Redaction failure: show the suspect tokens and stop. Never edit the
     proposal file to make it pass.
   - Success: Read the file and show it, then print the `gh issue create`
     line the script gave, for the engineer to run. Never run it yourself.
   - Nothing seen 3 or more times: say so; there is nothing to send.

## Output contract

```
Learning: <on|off|ask>
<the list | "added" | the proposal path and the gh command>
```

## Gotchas

- The log holds no code, prompts or repository names, and paths are
  reduced to extensions. A proposal that fails redaction means an entry
  carries a real name (an email, host, ticket id, address or URL). Fix
  the entry with the user; do not weaken the check.
- Only entries seen 3 or more times are proposed. One-off notes stay local.
- The engineer files the issue. This skill prints the command and stops.
