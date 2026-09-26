# <Your name>, <role> at <your company>

Personal notes for Claude Code on this machine. Kept short; every line is
loaded into every session.

## How I work

- Work repositories carry `AGENTS.md` and the Bearing skills. When unsure
  which step comes next, run `workflow`.
- One task per session. `start-task` to start, `session-handoff` to pause,
  `definition-of-done` then `merge-request` to finish.
- I push, merge and deploy. You prepare and print the command.

## Standing rules

- No em dashes in anything you write for me. Rewrite the sentence.
- No AI attribution in commits, MRs or documents.
- Report in the AGENTS.md shape: Changed, Verified, Not done, Noticed.
- If you did not run it, say "not run". Never claim a check you skipped.
- Ask one specific question when a request is ambiguous; otherwise proceed.

## Which skill

- Use the strongest skill for each step, whichever pack it comes from
  (Bearing, Superpowers, gstack, GSD Core, official plugins). A Bearing
  skill is used only where nothing installed does the step better; the
  handbook's skill pages show each comparison.
- When unsure which skill fits, run `workflow` or open the flow for
  the task (greenfield, bug fix, feature addition) in the handbook.
- Never on work repositories: cookie import, cross-model skills, deploy
  skills. The repository settings deny them.
