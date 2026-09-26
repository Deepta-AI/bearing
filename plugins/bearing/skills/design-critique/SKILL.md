---
name: design-critique
description: 'Scores a UI design (design gallery, running app or HTML prototype) at three widths, both themes, eleven categories, with an AI-slop check. Use when asked to "critique this design", "review the prototype" or "score this".'
argument-hint: "<folder, html file or URL> [--rounds N, default 3] [--report-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir:*), Bash(test:*), Bash(make:*), Bash(~/.claude/skills/gstack/browse/dist/browse:*), Bash(python3 -m http.server:*), Bash(kill:*), Bash(python3 *skills/design-critique/scripts/evidence.py*)
---

# design-critique

A review is a scored table with evidence, not a list of opinions. Every
finding names a file and line or a screenshot and says change X to Y
because Z. The first impression is written before the checklist: the
three things the eye lands on must be the three things the page is for,
and when they are not, the hierarchy is lying.

The default stack's designs live in the app: the design gallery at
`/__design` of a running dev server (`make dev`) or build shows every
screen in every state with the real components, and this skill reviews
it by URL, one page per screen and state
(`<id>?state=<name>&chrome=0`). HTML prototypes and static exports on
disk are reviewed the same way. Driving a deployed app's flows is
gstack `/design-review`'s job, which the workflow calls once the app runs.

## Inputs

- Target: looks in `$1` for a folder, an `.html` file or a URL; if
  absent, the design gallery when the app has `src/design/screen.ts`
  (start it with `make dev` and use `http://127.0.0.1:<port>/__design/`;
  the pages are every screen's states from the gallery index); if absent,
  the newest folder under `docs/design/` that holds html (variants,
  screens or an export); if none, asks once. Nothing after
  that: stop with "give a folder, an html file or a URL".
- The page's job: looks in `docs/design/flows/<feature>/flows*.md`
  (screen purposes, states, copy); if absent, the intent lines in
  `approved.json` or the board; if absent, the page's `<title>` and first
  heading, and the report says "job inferred".
- Design system: `DESIGN.md` or `docs/design/tokens.json`; a deviation
  from it is a finding; if absent, the doctrine alone.
- Screenshots: the gstack browse binary
  `~/.claude/skills/gstack/browse/dist/browse` when executable, driven by
  `scripts/evidence.py` in this skill; otherwise the source is the
  evidence and the report says screenshots not taken.
- Checklist: `references/review-checklist.md`. Doctrine: the hard rules
  and anti-slop list in `../design-directions/references/design-doctrine.md`
  when present; else the checklist's own slop section, which is the same
  list.
- Previous report: `docs/design/reviews/<feature>-review.md`; when
  present, per-category deltas are reported.

## Steps

1. Resolve the target; print each input as read or absent. Pages: every
   `.html` in the folder except `index.html` boards, or the one file, or
   the URL. Zero pages: stop as under Inputs.
2. A folder is loaded over `file://`; serve it only when a page needs
   http (fetch, modules): `python3 -m http.server 0 --bind 127.0.0.1
   --directory <folder>` in the background, the port from its first line,
   and pass `http://127.0.0.1:<port>/` as the base below.
3. Evidence when browse is executable, one command for every page:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py" shoot --base <folder or URL> --out docs/design/reviews/<feature>/shots <page>...`
   It shoots 375x812, 768x1024 and 1440x900 in light and in dark
   (`data-theme="dark"`), and records computed colours per theme and the
   console errors. Then gate the evidence:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py" check --out docs/design/reviews/<feature>/shots <page>...`
   Its counts line is the Evidence line of the report, verbatim. A dark
   shot identical to light is a colour finding (no dark theme), scored as
   one. Read every PNG; `snapshot -i` through browse for the control list.
   Without browse, read the source and cite `file:line`, and the Evidence
   line says `source only (browse absent)`.
4. First impression per page, before the checklist: the page communicates
   X; I notice Y; the first three things my eye lands on are A, B, C; one
   word. Compare A, B, C with the page's job. A mismatch is a hierarchy
   finding with the element and its position named.
5. Walk `references/review-checklist.md`: eleven categories, 0 to 10 each,
   one evidence line per point deducted. A category with nothing to judge
   is `n/a: reason` and leaves the mean. A slop hit caps its category at 3
   and always enters the top five.
6. Overall: weighted mean per the checklist; letter A 9 and above, B 8,
   C 6 to 7, D 4 to 5, F below 4. Top five fixes ordered by impact: where
   (file:line or shot), change X to Y because Z, expected delta.
7. Write `docs/design/reviews/<feature>-review.md` (first impressions,
   table, findings, top five, evidence paths) and print the contract.
   `--report-only` stops here.
8. Iteration, up to `--rounds` (default 3): present the top five and ask
   which to apply. Apply each approved fix as a surgical Edit to the page
   (a token change lands in `:root`, never a rewrite). Re-shoot the pages
   touched with `evidence.py shoot` and `check`, re-score the categories
   touched, append a round section with the delta. Stop when the user says so, when nothing is approved, or
   when the rounds are used.
9. Kill the server if one was started. Print the final contract.

## Output contract

```
## Design review: <feature or URL> (round <n> of <max>)
Pages: N   Evidence: <evidence.py check counts line, verbatim> | source only (browse absent)
Console errors: 0 | K (listed)
| Category | Score | Weight | Evidence |
| hierarchy | 7 | 15% | 1-name.html:42; 1-name-1440.png |
| ... ten more rows, consistency among them |
Overall: 7.4 (B)   Slop hits: 0 | K (listed)
Top fixes:
1. <where>: change X to Y because Z (+n)
... to 5
Findings: N   Fixes applied: K   Re-score: 7.4 -> 8.1 (+0.7)
Report: docs/design/reviews/<feature>-review.md
```

## Gotchas

- No evidence, no finding. A line without `file:line` or a shot name is
  not written.
- Never rewrite a page to fix a finding. The variant's identity is the
  user's choice; fixes are surgical and named.
- The Evidence line comes from `evidence.py check`, never from the
  reviewer's memory of what it shot. A page themed only by
  `prefers-color-scheme` shows as "no dark theme" here, because browse
  cannot switch the media query; say so, and add the `data-theme` path
  (themes) or review the running app with /design-review.
- Dark is a separate pass. Contrast that passes in light often fails in
  dark, and a missing dark theme is a colour finding, not a note.
- The slop detector scores the page against the list, not the reviewer's
  taste. "I would have picked another face" is not a finding unless a
  rule names the face.
- A board `index.html` is checked for legibility only and never scored.
- Kill the server; a stale `http.server` on a random port confuses the
  next run.
- `n/a` needs a reason ("no motion on the page"); it is never a free 10.
