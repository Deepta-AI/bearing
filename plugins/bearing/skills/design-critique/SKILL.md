---
name: design-critique
description: 'Scores a UI design (design gallery, running app or HTML prototype) at three widths, both themes, eleven categories, with an AI-slop check. Use when asked to "critique this design", "review the prototype" or "score this".'
argument-hint: "<folder, html file or URL> [--rounds N, default 3] [--report-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir:*), Bash(test:*), Bash(make:*), Bash(git status:*), Bash(git diff:*), Bash(~/.claude/skills/gstack/browse/dist/browse:*), Bash(python3 -m http.server:*), Bash(kill:*), Bash(python3 *skills/design-critique/scripts/*)
---

# design-critique

A review is measured findings against the page's own contract (its flows,
its design system, what the client approved), worst first, each one
located and each fix checked before it is proposed. Every finding names a
file and line or a screenshot and says change X to Y because Z. Numbers
come from a script, never from the eye: contrast is computed per theme and
per surface, and a proposed colour is recomputed before it is written.

The default stack's designs live in the app: the design gallery at
`/__design` of a running dev server (`make dev`) shows every screen in
every state with the real components; review it by URL, one page per
screen and state (`<id>?state=<name>&chrome=0`). HTML prototypes and
static exports on disk are reviewed the same way. Driving a deployed app's
flows is gstack `/design-review`'s job.

## Inputs

- Target: `$1` (folder, `.html` file or URL); if absent, the design gallery
  when the app has `src/design/screen.ts` (`make dev`, then
  `http://127.0.0.1:<port>/__design/`); if absent, the newest folder under
  `docs/design/` that holds html; if none, stop with "give a folder, an
  html file or a URL".
- The contract, read before any page: `docs/design/flows/<feature>/flows*.md`
  (each screen's job, every state, the exact copy), `DESIGN.md` or
  `docs/design/tokens.*` (type, colour, spacing, layout rules),
  `approved.json` or the board (what the client chose and must keep). If
  no flows exist, the page's `<title>` and first heading, and the report
  says "job inferred". These files are the yardstick; a review never
  edits them.
- The request's mode: "don't change", "review", "before they see it" or
  `--report-only` is report only; "fix", "clean up", "before handoff" is
  review then fix (step 8). Unattended with no signal: report only.
- Checklist: `references/review-checklist.md`. Doctrine:
  `../design-directions/references/design-doctrine.md` when present, else
  the checklist's slop section.
- Previous report: `docs/design/reviews/<feature>-review.md`; when present,
  per-category deltas are reported.

## Steps

1. Resolve the target and print each input as read or absent. Pages:
   every `.html` in the folder except `index.html` boards. Zero pages:
   stop. Run the repo's own check (`make check` or what the README names)
   and record its line; it is the baseline a fix must not break.
2. Measure colour with one command over the pages, plus every other page
   that links the same token file (find them with Grep; a token change
   lands on all of them):
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/pairs.py" <page>...`
   It prints every failing text pair, field edge and focus ring in light,
   data-theme dark and prefers-color-scheme dark with file:line (a ring is
   measured on the surface it is drawn on, so the same button can pass on
   the page and fail on a panel), outlines removed with nothing in their
   place, the raw colours in page styles, dark-block parity gaps, fonts
   asked for but never loaded, and a fix colour that passes on every
   surface the colour sits on. Its counts line goes in the report. Read
   its output as findings to verify in the source, not as the review: it
   skips hover states and width media queries (it says how many), so judge
   those from the CSS.
   Every ratio the report states comes from a `pairs.py` line or from
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/pairs.py" ratio <fg> <bg>...`
   run on the surface the finding is about; never a ratio remembered from
   another pair (text on white is not text on the grey panel).
3. Screenshots, one command for every page:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py" shoot --base <folder or URL> --out docs/design/reviews/<feature>/shots <page>...`
   then
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py" check --out docs/design/reviews/<feature>/shots <page>...`
   Shoot uses gstack browse (dark via `data-theme`) and falls back to a
   local headless Chrome (dark via `prefers-color-scheme`); its last line
   names which. Only that dark path was rendered; the other is known from
   `pairs.py` numbers alone, and the report says so. The check's counts
   line is the report's Evidence line, verbatim. Open every PNG you cite.
   If both engines fail, the Evidence line says `source only (no browser)`
   and every finding cites `file:line`; never describe a width or theme
   you did not shoot. A browser tool that leaves files in the repository
   (logs, state folders, often git-ignored) is debris: shoot removes what
   it finds and says so; anything else is removed or named in the final
   message.
4. First impression per page, before the checklist: the first three
   things the eye lands on, compared with the page's job from the flows.
   A mismatch is a hierarchy finding with the element named.
5. Contract diff, the findings a generalist misses most:
   - States: list every state and every line of copy in flows.md; each
     state with no page, and each page that shows a state the flows put
     elsewhere (an error baked into the default screen), is a finding.
   - Design system: each rule in DESIGN.md checked against each page
     (face, sizes, weights, raw colours, spacing scale, table overflow).
   - Content: the sample data must agree with itself: a status against
     its dates and against the day the audience will see it (Overdue with
     a due date still ahead), a total against its line items (add them),
     a count against its rows, rows in the order the flows name, the same
     record on two screens. A
     contradiction the client will read is high.
6. Walk `references/review-checklist.md`: eleven categories, 0 to 10, one
   evidence line per point deducted, `n/a: reason` leaves the mean. Score
   with its weights; letter A 9+, B 8, C 6 to 7, D 4 to 5, F below 4.
7. Verdict and report. Say plainly whether the design is ready for what
   the request names (the client on Friday, handoff), then the fixes that
   must come first, ordered by what the audience will see: broken or
   unreadable first, contract breaches next, polish last. Each fix: where,
   change X to Y because Z, and the measured result (a colour with its
   recomputed ratio on every surface it sits on, in the theme it serves).
   Write `docs/design/reviews/<feature>-review.md` and print the contract.
   Report only: stop here; `git status --short --ignored` must show only
   the review and its shots, and the final message names every file the
   run added.
8. Fix mode, up to `--rounds` (default 3). Unattended, apply without
   asking every high finding whose fix keeps the approved look: labels,
   focus rings, zoom, copy from the flows, missing states as new pages
   named like the existing ones, touch targets, token values that stay in
   the same hue. Propose, do not apply, anything that changes what the
   client approved (accent hue, face, layout, density) or adds a network
   dependency (a web-font link on pages opened from disk), and list it as
   a decision with both options measured. An AA failure the approved
   colours cause (white text on the accent, a pale ring, a faint edge) is
   not a decision: fix it inside the approved hue (the text colour on the
   fill, a darker shade of the same token), apply it, and name it as a
   visible change. Copy from the flows is pasted character for character,
   apostrophes included; typographic polish on it is proposed, not applied. Each fix is a surgical Edit; a
   colour lands in the token file, never as a raw value in a page; a new
   token goes into light and both dark blocks. After the round, rerun
   `pairs.py` over every page that links the tokens, the repo's own check
   from step 1, and `evidence.py shoot` and `check` for the pages touched
   (a change in the `prefers-color-scheme` block is verified by the
   `dark-media` lines, not by a `data-theme` screenshot);
   re-score the categories touched and append the round with its delta.
   A round that breaks the repo's check is reverted, not reported.
9. Kill the server if one was started. Final message: what changed per
   file, what was found and left (with why), the decisions for the owner,
   how the result was looked at (engine, widths, themes and dark path, or
   source only), and `git status --short --ignored`. Never commit.

## Output contract

```
## Design review: <feature or URL> (round <n> of <max>)
Pages: N   Evidence: <evidence.py check counts line, verbatim> | source only (no browser)
Colour: <pairs.py counts line, verbatim>   Repo check: <its line>
Verdict: ready | not ready for <what the request named>: <the blocking items>
| Category | Score | Weight | Evidence |
| hierarchy | 7 | 10% | list.html:42; list-1440.png |
| ... ten more rows, consistency among them |
Overall: 7.4 (B)   Slop hits: 0 | K (listed)
Fix first:
1. <where>: change X to Y because Z (measured result)
Decisions for the owner: <none | each with both options measured>
Findings: N   Fixes applied: K   Re-score: 7.4 -> 8.1 (+0.7)
Report: docs/design/reviews/<feature>-review.md
```

## Gotchas

- A token sits on more than one surface. `--text-muted` on the page and on
  the panel are two ratios; a replacement that passes on white can fail on
  the grey surface. `pairs.py`'s fix line already takes every surface in
  that theme; a colour typed by hand is recomputed with it first.
- A token change reaches every page that links the file, including screens
  outside the review. Name them in the fix.
- A raw colour in a page does not follow the theme. It is invisible in
  light and breaks dark (a white panel under near-white text). `pairs.py`
  shows it in the context it breaks; check dark on every raw colour.
- Two dark paths: `[data-theme="dark"]` and the `prefers-color-scheme`
  block. A token added to one only is a parity gap; the page is broken for
  users on the other path. A form control with no `color` inherits the
  browser's scheme, not the token: dark text on a dark field.
- A face named in CSS is not a face loaded. With no `@font-face` or font
  link the screen, and every screenshot of it, shows the fallback; the
  look the client approved may never have rendered. Report it; loading
  from a CDN is the owner's decision on pages opened from disk.
- WCAG thresholds: 4.5:1 body, 3:1 at 24 px or 18.66 px bold, 3:1 for a
  field's edge against its surround and for a focus ring against what is
  next to it. An amber ring passes on white and fails on a pale panel.
- A touch target is computed: font-size times line-height plus padding
  plus border. `height: 32px` on a button is 32, whatever the padding.
- Do not invent: a dark theme exists if either dark path sets tokens;
  status by colour alone only if no word is shown; read before claiming.
- Never rewrite a page to fix a finding. The variant's identity is the
  client's choice; fixes are surgical and named.
- The contract files (flows, DESIGN.md, approved.json) are never edited to
  make the prototype look compliant.
- A board `index.html` is checked for legibility only and never scored.
- Kill the server; a stale `http.server` on a random port confuses the
  next run.
