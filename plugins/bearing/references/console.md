# Console contract

Every Bearing skill that asks or reports follows this. It exists so a
session feels like one product.

## Asking

1. Infer first. Read the repository and, when the skill grants
   `brg-config`, `.bearing/config.json` (`brg-config get <key>`) and
   `bearing.env` (`brg-config get <key> --user`). A recorded answer is used
   silently; do not ask it again.
2. Confirm inferences instead of asking open questions: "I found a Go
   service with Postgres. Correct?"
3. Ask with AskUserQuestion: at most three questions a round, two to four
   options each, the recommended option first with "(Recommended)" in its
   label, and one sentence per option that states the trade-off in plain
   words a newcomer understands.
4. A skill that records answers grants `brg-config`; it records with
   `brg-config set` (project facts) or `brg-config set ... --user`
   (personal preferences). A skill without the grant records nothing and
   asks again next run. A recommendation the user did not pick is never
   recorded as their answer. No answer: record nothing and say in one line
   which default this run uses.
   When the user picks an option other than the recommended one, learning
   is on and the skill grants `brg-learn`, run `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-learn" log --kind override --skill <skill> --key <question id> --insight "<question>: chose <option> over <recommended>"`.
5. Prose fallback only when AskUserQuestion is unavailable; say so in one
   line, then ask the same options as a numbered list.

## Reporting

Lead with the result in one or two sentences, then the AGENTS.md shape:
Changed, Verified, Not done, Noticed. Every number comes from a command
that ran. No tours of every edit, no restated plan.
