# screen-design: HTML design bundle

Read when the target is not react-shadcn, or the gallery cannot run for the reviewer.

### HTML design bundle

1. When the repository already has mockups for the feature, extend them
in their own format and skip the manifest steps (9). Otherwise create
or update `docs/design/design.json` against the schema: `brief`,
`directions`, `stories`, a `sitemap` with a leaf per screen keyed
`<feature>/S-nn`, and a `navigation` generated from the flows'
section 4 maps (top-level destinations; three to five on the phone tab
bar; `why`; `source`).
2. Screen plan, one block per screen: its single job, the regions with
`data-component` names, the states from the reconciliation, the copy
per state, controls in tab order with event names, the links out (one
per navigation edge), the current item in the chrome, and the 375 px
arrangement: what moves, what docks, what drops to one line. A phone
layout that only stacks the desktop columns is not an arrangement.
Write the generic default answer next to each block; revise every line
that matches it.
3. Tokens: link the one tokens file; no page declares a colour. When
`docs/design/tokens.css` is absent and `tokens.json` exists:
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-system/scripts/system_page.py" tokens-css --tokens docs/design/tokens.json --out docs/design/tokens.css`.
4. Build `<id>-<name>.html` per screen from `templates/screen.html`: the
tokens link (or the `data-tokens` copy with `--standalone`), a state
bar, one `[data-state]` panel per state, each the whole screen: an
annotation (`data-annotation`), a desktop and a phone frame
(`data-frame`), each in its app chrome (`data-app-chrome`; `none:
<reason>` only for a screen with no chrome by design) with
`aria-current` on the current item. `#state=<name>`, `#state=all` and
`#chrome=0` deep links; a skip link, `:focus-visible` on every control,
44 px targets, labels bound by `for`, `data-event` only for names the
sheet has; fonts from Google Fonts only, no other external resource.
5. Self-review before anything is shown: the three things the eye lands
on are the screen's job; every button is a verb and its object; every
error says what happened and what to do; the phone frame is arranged,
not squeezed. Fix and count the findings.
6. States gate:
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/states_check.py" --screens docs/design/screens/<feature> --flows <flows file>`
(drop `--flows` when the inventory came from stories, code or a
brief; a state the screen truly lacks is marked `<!-- n/a: <state>
because <reason> -->`). States the reconciliation added beyond the
flows are checked by reading, and listed.
7. Screenshots when browse is executable:
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py" shoot --base docs/design/screens/<feature> --out docs/design/screens/<feature>/shots '<id>-<name>.html#chrome=0'...`
then `check`. Read every PNG; fix overflow or collapse and re-shoot.
8. Feature index `docs/design/screens/<feature>/index.html` from
`templates/index.html`: per screen the job, a link per state, the
screenshots (iframes when none) and the redlines (spacing, type roles,
token names, component names, events).
9. Manifest only: add the concerns, then
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/bundle.py" audit --design docs/design`,
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/bundle.py" gallery --design docs/design`,
`docs/design/DESIGN-SYNC.md` from its template, and
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/bundle.py" check --design docs/design`
until it exits 0. Never edit the `audit` block by hand; never run
`/design-sync` (the push to a shared design system is the person's).
