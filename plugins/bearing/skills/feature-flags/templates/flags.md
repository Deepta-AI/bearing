# Feature flags register

<!-- Template guidance: the register of every flag in code, kept in step
     with the flags module by scripts/flags_check.py, which fails on a flag
     on one side only. The team reads it in the weekly ops review. Every
     comment says what goes there (What), what a strong entry has (Good) and
     an example (Example). Delete each comment when you fill its section;
     keep the paragraphs, they are for the reader. -->

Every flag in code has one row here. `feature-flags` keeps the two in
step and fails on a mismatch. Owner is a rotation or team channel, not a
person. Target date is when the flag is removed, not when it is turned
on. A flag past its target date is raised in the weekly review.

Source of values: `FLAG_<NAME>` in the environment for services and web
builds; remote config key `<name>` with the bundled default for mobile.
Every flag defaults off.

## Active flags

<!-- What: one row per flag constant in the flags module, release,
     experiment, ops or kill switch.
     Good: default off; the owner is a rotation or team channel, never a
     person; a removal task id (task: tbd is a finding on the next audit)
     and a target date in YYYY-MM-DD, 90 days out by default; "on means"
     says what a user sees. A flag with no removal date belongs in config.
     Example: "bulk_report_upload | off | release | labs-oncall | the inbox
     accepts a zip of reports | ENG-471 | 2026-12-23 | 2026-09-24" -->

| Flag | Default | Kind | Owner | On means | Removal task | Target date | Added |
| --- | --- | --- | --- | --- | --- | --- | --- |

<!-- Example rows, to show the shape; delete this comment and add real
     rows to the table above:
       | new_checkout | off | release | payments-oncall | the new checkout flow serves instead of the old one | TASK-000 | 2026-12-21 | 2026-09-22 |
       | kill_recommendations | off | kill switch | growth-oncall | the recommendations panel returns an empty list | none, permanent switch reviewed yearly | 2027-09-22 | 2026-09-22 |
-->

Kinds: `release` (ships dark, removed once fully on), `experiment` (an
A/B with an analytics event, removed after the readout), `ops` (a
tuning switch with a config home to move to), `kill switch` (on means
the safe fallback; reviewed yearly, the only kind allowed to live past
a year).

## Removed flags

<!-- What: flags taken out of the code, moved here from Active on removal.
     Good: the removal date and which branch survived (on when the feature
     graduated, off when it was abandoned); a flag still in the module after
     it is listed here fails the audit.
     Example: "new_inbox_layout | experiment | 2026-09-18 | killed after the
     readout, off branch kept" -->

| Flag | Kind | Removed | Outcome |
| --- | --- | --- | --- |

<!-- Example rows, to show the shape; delete this comment and add real
     rows to the table above:
       | example_flag | release | 2026-09-01 | graduated, on branch kept |
-->

## How to turn a flag on

<!-- What: how to switch a flag per environment for each kind of build this
     repository has.
     Good: through the value source only, never by editing the default;
     remove the lines for stacks the repository does not have.
     Example: "- Services: set FLAG_BULK_REPORT_UPLOAD=true on the staging
     deployment and restart." -->

- Services: set `FLAG_<NAME>=true` on the deployment for one
  environment and restart. Never in `.env.example`.
- Web: `VITE_FLAG_<NAME>=true` at build time per environment; a
  per-user override through the flags module in development only.
- Mobile: change the remote config value for the environment; the app
  applies it on the next foreground. A bundled default is changed only
  in a release.

## Review

<!-- What: when the register is reviewed and what each overdue flag gets.
     Good: every flag past its target date gets a decision written in its
     row: remove now, extend with a reason and a new date, or convert to
     config.
     Example: "new_checkout: extended to 2027-01-15, payments migration
     slipped (ENG-502)." -->

Weekly in the team's ops review: every flag past its target date gets a
decision (remove now, extend with a reason and a new date, or convert
to config). The decision is written in the row.
