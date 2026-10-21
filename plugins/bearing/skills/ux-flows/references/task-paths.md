# ux-flows: task paths

Read when: writing the `## Task paths` section (step 8 of SKILL.md), or when the gate reports a task over budget.

One row per primary task: one per story the flows cover, or one per job
when there are no stories. One row per secondary task too (settings,
admin, anything done rarely). Header, exactly:

```
| Task | Story | Kind | Entry | Path | Screens | Interactions | Over |
```

Path syntax: `S-nn: action, action > S-nn: action > S-nn`. Segments are
joined by ` > `. Comma items inside a segment count one interaction each.
Every segment but the last needs at least one interaction (the one that
leaves that screen). The last segment is the success screen and has none.
Entry is the first screen of the path. Kind is `primary` or `secondary`.
Screens and Interactions are the counts the path has. Typing the content
itself (the name, the address) is not counted; the field is one tap.

Worked example:

```
| Invite a member | US-02-001 | primary | S-01 | S-01: tap Invite, tap Send > S-02 | 2 | 2 | |
```

Two screens (S-01, S-02), two interactions (tap Invite, tap Send).

## Budgets

| Kind | Screens | Interactions |
| --- | --- | --- |
| primary | 3 | 6 |
| secondary | 5 | 10 |

A project may set its own. Each key is flat in `.bearing/config.json`:

```
bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-config" set ux.budget.primary.screens <n>
bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-config" set ux.budget.primary.interactions <n>
bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-config" set ux.budget.secondary.screens <n>
bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-config" set ux.budget.secondary.interactions <n>
```

## Over budget

Redesign with the patterns below first. Write `over: <reason>` in the
Over cell only for a legitimate reason:

- a legal confirmation (terms, consent) the law requires
- a payment step the provider owns
- the confirmation of a destructive or irreversible action

A confirmation on a destructive action is kept and counted, never dropped
to fit the budget. Write `over: destructive action confirmation`.

## Six patterns that inflate paths

- Confirmation on a reversible action: do it and offer undo.
- A separate page for a short create or edit form: inline, or a sheet.
- A wizard for under five fields: one form.
- Navigating away to pick a related item: an inline picker.
- An empty state with no primary action: put the action in the empty state.
- A success page that is a dead end: return to the list with the new item highlighted.
