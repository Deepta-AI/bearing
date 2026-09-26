---
name: company-attribution
description: 'Sets who owns a repository: organisation profile, LICENSE and NOTICE, CODEOWNERS, SECURITY.md, package metadata. Use when asked to "add a licence", "attribute this repo to" or "who owns this code".'
argument-hint: "init | license <proprietary|apache-2.0|mit|custom> | apply | show"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(git remote:*), Bash(git log:*), Bash(date:*)
---

# company-attribution

The kit itself names no company. A repository names one through
`.bearing/company.json`, and the skills that produce client-facing or legal
text (handover, HLD, VAPT, licence, headers) read it from there. Without
the profile they write "unattributed" rather than guessing.

## Inputs

- Subcommand: looks in `$1`; if absent, `show`.
- Profile: looks in `.bearing/company.json`; if absent, `show` says the
  repository is unattributed and offers `init`; `apply` and `license`
  run the `init` questions first instead of stopping.
- Defaults for `init`: git host and group from `git remote -v`, org id
  and author from package metadata, start year from the first commit;
  each is offered as the default of its question, never written unasked.
- Licence text: `templates/licenses/` in this skill; `custom` comes from
  the user. The kind itself is always asked; that is a legal decision.
- Templates: `templates/company.json`, `templates/NOTICE.md` and
  `templates/header.txt` in this skill.

## Steps

1. `show`: print `.bearing/company.json` if present, else say the repository
   is unattributed and offer `init`.
2. `init`: ask, one question at a time, for what `templates/company.json`
   lists: display name, legal name, short id (lowercase, used in ids and
   paths), primary domain, reverse-domain org id (`com.example`), git host
   and group, tracker (name and key shape), security contact (a mailbox
   or a page, never a person's name), copyright holder and start year,
   default licence, delivering entity for handovers (defaults to the legal
   name), and optional secondary entities the user may name per project.
   Write `.bearing/company.json`. Commit it with the repository; it is not a
   secret.
3. `license <kind>`: copy the licence from `templates/licenses/` with the
   year and holder filled: `proprietary` (all rights reserved, the default
   for client work), `apache-2.0`, `mit`, or `custom` (the user supplies
   the text). Refuse to change an existing LICENSE of a different kind
   without an explicit yes; that is a legal decision, not a formatting one.
4. `apply` (also runs after `init`; without a profile it runs `init`
   first): fill every placeholder and stale value from the profile:
   - `CODEOWNERS`: `__LEAD__` and `__TEAM_GROUP__` from the profile's
     lead and group handles.
   - `SECURITY.md`: the reporting contact.
   - `README.md`: a one-line attribution at the bottom ("Maintained by
     <name>. Licensed under <licence>.").
   - `NOTICE.md` from `templates/NOTICE.md` when the licence requires or
     the user wants third-party attributions listed.
   - Package metadata where the stack has it: `author` in `package.json`,
     `authors` in `pyproject.toml`, `organization` in `project.yml`,
     `namespace` and `applicationId` from the org id in Gradle.
   - Bundle and app ids that still read `com.example` become the org id.
   - The delivering entity line in `docs/handover/*` and the title pages
     of `docs/design/*` when those exist.
   Print a count of files changed and the list.
5. Optional copyright headers: only when the profile sets
   `"headers": true`; then add the one-line header from
   `templates/header.txt` to source files that lack it, per stack comment
   syntax, and add the check to `make check` as `headers-check`. Off by
   default because most teams do not want them.
6. Report in the fixed shape. Under Not done: anything the user must
   decide (licence kind, a second entity).

## Output contract

```
company: <display name> (<legal name>) org <com.example> licence <kind>
profile: .bearing/company.json (written | unchanged)
license: LICENSE (<kind>, <year>, <holder>) NOTICE.md (yes | no)
applied: <N> files (CODEOWNERS, SECURITY.md, README.md, ...)
```

## Gotchas

- Never invent a legal name, a year or a licence. Ask.
- A licence change on a repository with external contributors needs
  every contributor's consent for the past commits; say so and stop at
  writing the new file for the user to review.
- The profile holds no secrets and no personal names: handles for
  CODEOWNERS, a shared mailbox for security, an entity for delivery.
- Multi-entity companies (one delivering entity per client) keep every
  entity in `entities` and the default in `delivering_entity`; a
  handover (`client-handover`) names one, never both.
