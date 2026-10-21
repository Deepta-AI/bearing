# design-system: the lint

Read when: the lint section: installing design-lint.sh, gating, baselining and proving it fails.

Install `templates/design-lint.sh` as `scripts/design-lint.sh` (POSIX sh
and awk: runs on alpine, busybox and macOS without bash, python3 or
node) and add `design-lint` under `check` in the Makefile. It strips
comments, skips the token and generated files, and counts per occurrence:
hex, `rgb()`, `hsl()`, `oklch()`, `color-mix()` and named colours;
spacing and font sizes off the scale, including px inside style-object
strings (`padding: "6px 12px"`), rem at 16 px, and Tailwind arbitrary
values; shadows on non-pressable elements; raw `<button>`, `<input>`,
`<table>` and friends outside `components/ui` (`DESIGN_LINT_LIBRARY` for
another library folder); one-off font families. It is pattern-based: a
colour built in a variable named `brand`, or a value split across lines,
is missed, so review the diff too. A Tailwind 3 config reading
`hsl(var(--x))` with a hex in `--x` compiles and renders nothing; grep
the config before writing a value (Read the repo, item 1).

1. Gate only what was asked: set `DESIGN_LINT_RULES` in the Makefile
(colour, spacing, font-size, shadow, raw, family). "Colours and px"
means `colour spacing font-size`; the other rules are offered in the
report, because a rule nobody agreed to fails someone's next merge
request. On-scale literals pass; the gate is for values off the scale.
Check the scale source line it prints: the scale must be the one the
team means (step 4 of Read the repo). Set `DESIGN_SPACE_SCALE` and
`DESIGN_FONT_SCALE` in the Makefile when the tokens do not state it.
Vendored code (`vendor/`, `*.min.css`, a header saying it is copied
from a package) is excluded, not baselined: it is not the team's debt
and its next upgrade would fail the gate.
2. Read every finding before baselining. A false positive is a lint bug:
fix the template's pattern or exclude the path, never baseline it.
Report today's debt per category with file and line.
3. Existing debt: fix a literal only when a token holds the same value
in both themes; a literal with no matching token stays as debt (a
near match is a visual change, and needs saying). Record the rest with
`sh scripts/design-lint.sh --write-baseline`. The baseline is keyed by
file and literal with a count, so a new literal anywhere, including a
second copy on an old line, fails, and paying a debt does not make
room for another. A total allowance (`ALLOW_COLOR=7`) is not a ratchet.
Paying a debt also fails until the baseline is lowered in the same
change; tell the team that, with the command, in the report.
4. Prove it: add a new colour and an off-scale value in a scratch file,
run `make check`, see it fail, remove them. If the check has tests,
they run under `make check` in the CI image too.

## The hash check (tokens-sync)

Installed only when `docs/design/tokens.json` holds `meta.sourceHash`
(tokens derived from root `DESIGN.md` frontmatter or a picked direction in
`approved.json`). It is a mode of the same installed script, so no second
file is copied: add a `tokens-sync` target running
`sh scripts/design-lint.sh --sync` and list it under `check` next to
`design-lint`. A rerun of design-system from a source with no hash
removes the target with `meta.sourcePath` and `meta.sourceHash`. Its lines,
where `<source>` is `meta.sourcePath` (`DESIGN.md`, or
`docs/design/variants/<feature>/approved.json` for a picked direction):

- pass: `tokens-sync: 1 source checked, <source> matches tokens.json (sha256:<first 12>)`
- drift: `tokens-sync: 1 source checked, failed`, then
  `tokens-sync: <source> is sha256:<new>, tokens.json was derived from sha256:<old>; rerun design-system to re-derive the tokens`
- moved source: an `approved-direction` source with root `DESIGN.md` now
  carrying frontmatter tokens prints the same count line, then names both
  files
- zero input: `tokens-sync: 0 sources checked (<file> missing)` or
  `(no meta.sourceHash in <tokens>)`
- no hasher: `tokens-sync: no sha256 tool (sha256sum, shasum or openssl)`

Each failure exits 1. `DESIGN_TOKENS`, `DESIGN_SOURCE` and `DESIGN_ROOT`
override the paths (the script header says how). Prove it as in item 4:
append a line to the source, see `make check` fail with both hashes,
revert it.
