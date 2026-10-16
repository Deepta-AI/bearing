---
name: design-system
description: 'Turns a design direction into a design system: oklch tokens, per-stack themes, a component contract, an every-state page and a lint. Use when asked to "set up the design system", "make design tokens" or "lint colours".'
argument-hint: "[DESIGN.md | variant dir | CSS file | brief text] [--stack web|react-native|android|ios] [--lint-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(make:*), Bash(python3:*), Bash(python3 *skills/design-system/scripts/contrast.py*), Bash(python3 *skills/design-system/scripts/system_page.py*), Bash(sh scripts/design-lint.sh:*), Bash(bash scripts/design-lint.sh:*), Bash(git diff:*)
---

# design-system

A design direction is prose; a design system is code that a lint can
hold to. This skill writes the tokens once, binds every stack's theme to
them in the form that stack already consumes, and installs a lint that
keeps new literals out. On a full setup it also writes the component
contract and `docs/design/design-system.html`, every component in every
state in both themes, generated from the tokens.

## Inputs

- Direction: `$ARGUMENTS`, else root `DESIGN.md` or `docs/design/DESIGN.md`,
  else `docs/design/variants/*/approved.json`, else the app's current
  styles, else a one-question brief (step 1).
- Stack: `--stack`, else the autopilot profile, else detected
  (`components.json` with react: react-shadcn; `expo`: react-native;
  `build.gradle.kts`: android; `Package.swift` or `*.xcodeproj`: ios).
- This skill's files: `templates/tokens.schema.json`,
  `references/stack-bindings.md` (per-stack forms, sRGB conversion, the
  browser floor), `templates/components.md`, `templates/DESIGN.md`,
  `templates/design-lint.sh`, `scripts/contrast.py` (loads themes's
  `theme-lint.py`; absent, the contrast line says not run),
  `scripts/system_page.py`.
- An existing `docs/design/tokens.json` is updated in place, never
  rewritten without naming the changed roles.

## Scope first

Match the output to the request. "Set up the design system" is the full
procedure below. "Turn DESIGN.md into tokens and hook the app up" is
steps 1 to 7 and the report; "add a check for hardcoded styles" is the
lint section alone. The contract, the page and the guide are offered in
the report when they were not asked for, not produced.

The direction is someone's agreement (a client, a brand owner). Never
rewrite it, move it or replace it with a symlink. Do not change what the
request did not touch. Detail: references/direction-and-scope.md

## Read the repo before choosing a value

A generalist writes correct tokens in the wrong form. Settle these from
the files, and name each answer in the report: (1) what consumes the variables (Tailwind 3 `hsl(var(--x))` needs HSL
channels, not hex); (2) the browser floor, no known floor means sRGB;
(3) the dark switch, one selector in the toggle, the CSS and the
framework's dark variant; (4) which document wins; (5) where the checks
run (bash or python3 checks do not run on `node:*-alpine`). Detail: references/read-the-repo.md

## Steps

1. Resolve the direction: `$ARGUMENTS`, else root `DESIGN.md` or
   `docs/design/DESIGN.md`, else `docs/design/variants/*/approved.json`,
   else the app's current styles read as the de facto system, else ask
   once for a brief. `--lint-only`: go to the lint section. Detail:
   references/roles-and-type.md
2. **Measure the direction before designing.** Compute the contrast of
   every pair it implies with `scripts/contrast.py` or the WCAG formula;
   a failing pair keeps its hue and moves in lightness. Detail:
   references/roles-and-type.md
3. Colour primitives in oklch, every sRGB value computed with the
   snippet in `references/stack-bindings.md`; refuse the default looks
   unless the direction names one. Detail: references/roles-and-type.md
4. Roles for light, then dark designed on its own; never invert. Text
   pairs 4.5:1, focus rings, borders and icons 3:1, in both modes. Detail:
   references/roles-and-type.md
5. Type and shape. A face the direction names is the face, with its
   fallbacks and how it loads; a different face is at most a proposal.
   Detail: references/roles-and-type.md
6. Write `docs/design/tokens.json` (schema `templates/tokens.schema.json`,
   validate with `uvx --with jsonschema==4.25.1 python -c "import json,jsonschema; jsonschema.validate(json.load(open('docs/design/tokens.json')), json.load(open('<schema>')))"`
   (stdlib Python has no validator; without uv, say "schema: not
   validated"); update an existing file in place with
   `meta.version` bumped and the changed roles named). Measure:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-system/scripts/contrast.py" --tokens docs/design/tokens.json --strict-hex`.
   Its count line is the report's contrast line, verbatim; zero pairs
   checked is a failure; a failed pair goes back to step 4. Detail:
   references/write-and-bind.md
7. Bind each stack per `references/stack-bindings.md`, in the form the
   repo consumes (Read the repo, 1 to 3); on react-shadcn never a parallel
   `--color-*` set the components do not read. Detail: references/write-and-bind.md
8. Full setup only: `docs/design/components.md` from
   `templates/components.md`. Then `system_page.py tokens-css`, `build`
   and `check` (paths in the script's help; `build --fonts-css <file>`
   links the product's own `@font-face` stylesheet, and `--google-fonts`
   is only for a product that loads its faces from Google); `check` must
   exit 0; open the page in both themes. Write `docs/design/DESIGN.md`
   from `templates/DESIGN.md`. Detail: references/write-and-bind.md
9. The lint (next section) and `make check`.

## The lint

Install `templates/design-lint.sh` as `scripts/design-lint.sh` (POSIX sh
and awk: runs on alpine, busybox and macOS without bash, python3 or
node) and add `design-lint` under `check` in the Makefile. Detail:
references/lint.md

1. Gate only what was asked: set `DESIGN_LINT_RULES` in the Makefile
   (colour, spacing, font-size, shadow, raw, family); a rule nobody
   agreed to fails someone's next merge request, so the others are offered
   in the report. Vendored code is excluded, not baselined. Detail:
   references/lint.md
2. Read every finding before baselining. A false positive is a lint bug:
   fix the template's pattern or exclude the path, never baseline it.
3. Existing debt: fix a literal only when a token holds the same value
   in both themes; record the rest with
   `sh scripts/design-lint.sh --write-baseline`. Paying a debt also fails
   until the baseline is lowered in the same change; tell the team that,
   with the command, in the report. Detail: references/lint.md
4. Prove it: add a new colour and an off-scale value in a scratch file,
   run `make check`, see it fail, remove them. If the check has tests,
   they run under `make check` in the CI image too.

## Output contract

Changed, Verified, Not done, Noticed. Lead with anything that was broken
before (dark mode never switching, variables in a form the config
cannot read). Then:

```
direction: <source>; stack: <binding form, e.g. Tailwind 3 HSL channels>; floor: <browsers, source>
dark switch: <what toggles> = <CSS selector> = <framework variant>
contrast: <contrast.py count line, verbatim>; extra pairs: <hover, link on card, ring> <ratios>
proposals for the direction's owner: <each change with measured before and after>
design-lint: <count line, verbatim>; baseline <n> keys; new-literal proof: failed as expected | not run
gate: make check: passed | failed (<target>) | no Makefile
not run: <build, device on the browser floor, CI pipeline> (say which; never claim them)
```

## Gotchas

- Tailwind 3 and 4, React Native, Material 3 and SwiftUI each have a trap
  that renders nothing or breaks theming. Detail: references/gotchas-by-stack.md
- The lint is pattern-based: a colour built in a variable named `brand`,
  or a value split across lines, is missed. Review the diff too.
- The design-system page is generated; change the tokens or the
  contract and build again, never hand-edit it.
- A hover or active specimen is drawn with an `is-*` class because a
  static page cannot hold the pointer; a component that styles only
  `:hover` still needs the class rule.
- Other inputs: gstack `design-consultation` writes a direction as
  DESIGN.md prose and GSD `gsd-ui-phase` writes a UI-SPEC per phase;
  either is read as the direction.

