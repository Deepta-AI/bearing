# Impeccable in Bearing

Read when a design skill (design-directions, design-system, screen-design,
design-critique) reaches its impeccable step. Impeccable (pbakaus/impeccable,
pinned in `bin/pinned-packs.txt`) does the visual work; Bearing keeps the
flows, the tokens code binds to and the measured gates. The sections below
are shared; each calling skill then reads its own section at the end.

## Detect

1. The `impeccable` skill is listed in this session: installed.
2. Else `test -f ~/.claude/skills/impeccable/SKILL.md`,
   `test -f ~/.agents/skills/impeccable/SKILL.md` or (project scope)
   `test -f .agents/skills/impeccable/SKILL.md` exits 0: installed (the
   session started before the install; say so once).
3. Else: print `impeccable not installed` once, take the skill's fallback,
   and never ask whether to install it (`brg-install-packs` does that).

## Invoke

The Skill tool with skill `impeccable` and the command as its argument, for
example `document --seed S-01` or `audit src/features/invite`. Never the bare
`polish`, `audit`, `critique` or `harden` skills: in the full profile those
names belong to ui-craft, not impeccable. Each call carries a brief: the
flows file (`docs/design/flows/<feature>/flows*.md`), `docs/product/PRD.md`
when present, the constraints the skill found (ADRs, CSP, device size,
contrast and motion floors) and, after a direction exists, `DESIGN.md` and
`docs/design/tokens.json` as the binding system. Impeccable's own setup
(`scripts/impeccable context`, and the scripts its references name) runs
inside its skill; Bearing runs none of them.

## Unattended

A run is unattended when any of these holds:

- the skill was called with `--unattended` (autopilot);
- `printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE` prints a value other
  than `0` (it prints the value of each one that is set, one per line, with
  no name; `BEARING_AUTOPILOT` set and not `0`, or
  `BEARING_NONINTERACTIVE=1`, is unattended, and an unclear value errs
  toward unattended);
- `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-config" get noninteractive --user`
  prints `1` (the `BEARING_NONINTERACTIVE=1` line in `bearing.env`).

Unattended, no impeccable command that asks the user runs. Only `audit`,
`polish` and `harden` run, each with the full brief so impeccable infers
instead of asking. `critique` asks at its close whenever it lists 3 or more
priority issues, so it does not run unattended; `audit` covers that review.
`init` and `document` (seed or scan) always ask, so the direction round falls
back to Bearing's doctrine.

## Commands

Read from impeccable's own `reference/` files (version 4.5.2; the pinned
commit carries 4.6.0, so recheck these six rows whenever the pin moves).

| Command | Bearing skill | Asks? | Unattended |
|---|---|---|---|
| `init` | design-directions | yes, one answer round before a new PRODUCT.md (init.md step 3) | not run |
| `document --seed` | design-directions | yes, the world workshop's decision page (document.md seed mode, new-work.md section 2), and before overwriting an existing DESIGN.md; no second ask when new-work already ran this session | not run |
| `document` (scan) | design-directions, on an app with an incumbent system | yes, two rounds on the qualitative language (document.md scan step 3), and before overwriting an existing DESIGN.md | not run |
| `polish` | screen-design | only when a binding principle cannot be inferred or a claim would change (polish.md section 1, copy rule) | run when `DESIGN.md`, `docs/design/tokens.json` and the flows file are on disk (binding system named, copy fixed); else not run (screen-design section) |
| `harden` | screen-design | no | run, with the flows' copy as the only copy |
| `audit` | design-critique | no | run |
| `critique` | design-critique | yes, at its close when it lists 3 or more priority issues (critique.md Ask the User) | not run; audit only |

Any other impeccable command is outside Bearing's pipeline: the user may run
it, and the next Bearing gate judges the result.

## Inferred facts

Every fact impeccable labels inferred (a user, a tone, a constraint it did not
find written down) goes in the calling skill's report as `inferred: <fact>`,
and in `approved.json` `inferred` on the direction round. None:
`inferred: none`. An inferred fact never overrides a written constraint; when the two
disagree, the written one wins and the pair is listed.

## Copy and gates

- The flows own the copy. A copy change impeccable proposes is listed as
  proposed, not applied; copy it wrote anyway is reverted to the flows'
  words.
- Bearing's gates run after every impeccable edit (pairs.py or contrast.py,
  the state and gallery checks, design-lint, the DESIGN.md hash check when
  installed). A gate that fails gets one fix in the screen; if it still
  fails, the file is reverted and listed with the gate line it broke (the
  snapshot rule in the screen-design section).
- Impeccable output is never described as seen on screen unless Bearing's
  own screenshots were taken.

## design-directions

Which path (step 1, after the inputs): Detect, then Unattended.

- Installed and attended: the impeccable round below.
- Installed and unattended: print
  `impeccable direction round skipped: unattended (it needs an answer)`
  and run the fallback.
- Not installed: `impeccable not installed`, the fallback.

The impeccable round, in order:

1. Root `DESIGN.md` is the link design-system adds for gstack
   (`readlink DESIGN.md` prints `docs/design/DESIGN.md`): `rm DESIGN.md` removes the
   link only, the guide it pointed at stays; say so. Any other link or file
   is left alone, and impeccable's own overwrite question decides it.
2. `PRODUCT.md` absent: `init` (its one answer round writes it).
3. Which mode. An app with an incumbent system (`docs/design/tokens.json`,
   a token CSS file or themed components found in skill step 2):
   `document <first screen of the happy path>` in scan mode, which writes root `DESIGN.md`
   with frontmatter tokens and `.impeccable/design.json` from the code
   (impeccable offers scan, not seed, when a system exists). The direction
   is then the fallback's three variants with colour and faces frozen by
   that system, `approved.json` with `"source": "bearing"`, and the report
   says `Impeccable: document (scan)`. Steps 4 to 9 below do not apply.
   Scan stopped or failed before writing `DESIGN.md`: restore the link
   removed in step 1 as step 6 says, say why, and continue with the three
   variants frozen to the system in the code.
4. No incumbent system: `document --seed <first screen of the happy path>`
   with the brief: the flows path, the PRD, the constraints and audit
   findings from skill steps 1 and 2. Impeccable runs its direction work once: one
   assigned direction plus challengers on its own decision page, where the
   user picks. Bearing asks nothing about the direction itself; the pick
   there is the choice.
5. The seed `DESIGN.md` carries only `name` and `description` in its
   frontmatter and no `.impeccable/design.json` (document.md seed mode), so
   the locked card's payload is the token source until code exists. Write
   `docs/design/variants/<feature>/approved.json` now:
   `{"round": 1, "date": "2026-10-18", "source": "impeccable", "chosen": "harbour", "challengers": ["ledger", "atlas"], "recommended": null, "direction": {"palette": {"background": "#f4f1ea", "accent": "#1f4e79"}, "faces": {"display": "Literata", "text": "system-ui"}, "radius": "6px", "spacing": "4px base", "motion": null}, "inferred": ["phone users on site"], "evidence": {"contrast": null, "screenshots": null}, "notes": ""}`
   (example values). `chosen` is the picked direction's name; `challengers`
   names every challenger it was chosen over, demoted ones included;
   `direction` holds whatever the card carries (palette roles and values,
   faces, radius, spacing, motion), a value the card leaves open is `null`
   and named in the report.
6. No pick: the user stopped, impeccable failed, or impeccable went on with
   its assigned direction without an answer (its no-answer continuation).
   Write nothing as chosen, restore the link removed in step 1
   (`ln -s docs/design/DESIGN.md DESIGN.md`, only when `test -e DESIGN.md`
   fails), say why, and offer the fallback; no direction becomes the
   default. A `DESIGN.md` impeccable wrote before stopping stays as it is,
   is never replaced by the link, and the report names it.
7. Bearing renders the picked direction over the real screens: one
   `1-<name>` page (skill step 7) or one theme (skill step 6), from `DESIGN.md`'s
   frontmatter tokens when present, else from `approved.json` `direction`,
   with the flows' copy word for word; then skill steps 8 and 9 (pairs.py,
   evidence.py) and their fixes. Steps 3 to 5 of the skill (plan,
   distinctness, generic default) do not run: impeccable's roll and its
   challengers did that work.
8. The board (skill step 10) has one column: the direction, the user it serves,
   the shots and the evidence lines. It keeps rating and comment for
   feedback and drops the chosen radio: the choice was made on impeccable's
   page, and the board never offers a second one. Skill step 10 fills `evidence`
   with the pairs.py counts line and the evidence.py check line.
9. `--round 2` on this path reruns step 4 with the chosen direction's traits
   in the brief; impeccable asks before replacing `DESIGN.md`; `round`
   becomes 2, `chosen`, `challengers` and `direction` are rewritten, and
   round one's values move under `previous`.

The fallback is today's three Bearing variants under
`references/design-doctrine.md`, unchanged, and `approved.json` in today's
shape plus `"source": "bearing"`.

## design-system

Token source, first that exists: the frontmatter tokens of root `DESIGN.md`
(any of `colors`, `typography`, `rounded`, `spacing` in its YAML
frontmatter: scan mode on an app with an incumbent system, or impeccable's
finish step after screens), else `direction` in the newest
`docs/design/variants/*/approved.json` that holds one (a seed `DESIGN.md`
holds only `name` and `description`; Bearing's fallback `approved.json` has
no `direction`), else today's inputs. Every value is a file fact, so this
path needs no Detect and asks nothing; no impeccable command runs here, so
the unattended rule changes nothing.

Mapping onto `templates/tokens.schema.json`:

- From `DESIGN.md` frontmatter: `colors` become oklch primitives and the
  light roles (the primary or brand entry is the accent; neutral entries
  set the neutral hue and scale); `typography` roles become
  `font.families` and `font.sizes`; `rounded` becomes `radius`; `spacing`
  becomes `space.scale`. The `.impeccable/design.json` sidecar adds
  `colorMeta` ramps, motion and breakpoints where present.
- From `approved.json` `direction`: `palette` roles and values, `faces`,
  `radius`, `spacing` and `motion` the same way. A `null` value is a
  placeholder: design-system fills it and lists it as a proposal for the
  direction's owner.
- Dark roles are designed by steps 3 and 4 as today, never copied from a
  light value. A value that fails contrast follows step 2's rule.

`meta.source` is `design-md` or `approved-direction`, `meta.sourcePath` is
the file (`DESIGN.md`, or the `approved.json` path), and `meta.sourceHash`
is the line
`sh "${CLAUDE_PLUGIN_ROOT}/skills/design-system/templates/design-lint.sh" --hash <sourcePath>`
prints (sha256 of the file's bytes, by `sha256sum`, `shasum -a 256` or
`openssl`, whichever exists). The repository's check is
`sh scripts/design-lint.sh --sync` under `make check` (target
`tokens-sync`): it hashes the same source and fails with both hashes and
the path when it changed, fails when the source was `approved-direction`
and root `DESIGN.md` now carries frontmatter tokens (the source has moved),
and fails with `tokens-sync: 0 sources checked (<what is missing>)` on no
tokens file, no `meta.sourceHash` or no source. Rerunning design-system
re-derives the tokens and the hash without writing `DESIGN.md`, so the
check cannot loop. A rerun that falls back to a source with no hash
removes `meta.sourcePath`, `meta.sourceHash` and the `tokens-sync` target.

Links (step 8, full setup; on a narrower scope the link is offered in the
report): design-system never writes the root `DESIGN.md`. When it is a file
(not a link) and `docs/design/DESIGN.md` is absent or still the unfilled
template (it holds `<!-- Template guidance` or `(v<version>)`),
`ln -sf ../../DESIGN.md docs/design/DESIGN.md` replaces it with a relative
link to the root. A filled guide is never replaced, moved or deleted; it,
and any other state (a root link, no root file), stays as it is and is
reported under Noticed. Bindings, contrast and design-lint are unchanged.
Without either source, the skill writes `docs/design/DESIGN.md` from its own
template as before, and links the root to it only when no root file or link
exists.

## screen-design

After every screen and every flow state exists, per feature: `harden <screen set>`
on the loading, empty and error panels, then `polish <screen set>`. The target
is the views under `src/features/<feature>/components/` (react-shadcn) or the
pages under `docs/design/screens/<feature>/`. Brief: the flows file (its copy
fixed), `DESIGN.md` and `docs/design/tokens.json` as the binding system.
A state the flows lack is raised as a gap, never written.

Snapshot, before `harden`: list the target files, then for each one
`mkdir -p .scratch/impeccable-pass/<its directory>` and
`cp -p <file> .scratch/impeccable-pass/<file>` (same relative path). A revert
is `cp -p .scratch/impeccable-pass/<file> <file>` for the files of the target
set only. Never `git checkout`, `git restore` or `git stash`, never a file
outside the target set, never a person's uncommitted work elsewhere.

Gates, after polish (or after harden when polish is skipped): `gallery_check.py`
or `states_check.py`, `bundle.py check`, `contrast.py`, `sh scripts/design-lint.sh`
and `sh scripts/design-lint.sh --sync`. The sync check runs only when
`docs/design/tokens.json` has `meta.sourceHash` (design-system's rule); else it
is skipped and the report says so. A gate that fails gets one fix in the
screen, never by weakening the gate; if it still fails, that file is reverted
from the snapshot and listed with the gate line it broke (terminal). A change
impeccable wants at token level (a colour, a face, a radius, a scale step) is
listed and routed back to design-system; `tokens.json` is not edited by hand.

Unattended (see Unattended above): `harden` never asks, so it runs. `polish`
asks only when a binding principle cannot be inferred or a claim would change,
so it runs unattended only when both can be answered from files: the binding
system is on disk (`docs/design/tokens.json` and a `DESIGN.md`, at the root or
under `docs/design/`) and the brief fixes the copy (the flows file exists, and
a copy change is listed as proposed, never applied). Otherwise unattended runs
harden only and the report says
`polish skipped: unattended (<the missing binding system or flows file>)`.
A polish that reaches a question anyway is stopped, its target files are
reverted from the snapshot and `polish skipped: unattended (asked)` is printed;
nothing is answered on the user's behalf.

The report says
`Impeccable: harden <n> and polish <n> screen sets | not installed; inferred: <facts> | none`
(`polish 0` with the skip line when skipped). Absent, the screens follow
`design-doctrine.md` and no pass runs.

## design-critique

`audit <target>` runs whenever impeccable is installed; `critique <target>`
runs attended only. Each finding joins the review with its source kept
(`source: impeccable audit` or `source: impeccable critique`). Bearing's
measured checks stay Bearing's: contrast pairs, widths, themes and copy
against the flows. An impeccable finding that contradicts a measurement is
listed with both, and the measurement decides the score. The report says
`Impeccable: audit N findings, critique N | critique not run (unattended) | not installed`.
