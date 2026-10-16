# design-system: writing tokens.json, binding each stack and the full setup

Read when: steps 6 to 8: after the roles pass contrast.

6. Write `docs/design/tokens.json` (schema `templates/tokens.schema.json`,
validate with `uvx --with jsonschema==4.25.1 python -c "import json,jsonschema; jsonschema.validate(json.load(open('docs/design/tokens.json')), json.load(open('<schema>')))"`
(stdlib Python has no validator; without uv, say "schema: not
validated"); update an existing file in place with
`meta.version` bumped and the changed roles named). Measure:
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-system/scripts/contrast.py" --tokens docs/design/tokens.json --strict-hex`.
Its count line is the report's contrast line, verbatim; zero pairs
checked is a failure; a failed pair goes back to step 4. Then measure
the extra pairs from step 4 on the values as written in the binding
(rounded HSL channels are not the hex they came from).
7. Bind each stack per `references/stack-bindings.md`, in the form the
repo consumes (Read the repo, 1 to 3). On react-shadcn: one file of
the variables shadcn reads (`src/styles/tokens.css` or `src/index.css`
itself), replacing the defaults shadcn init wrote, never a parallel
`--color-*` set the components do not read. Each generated file
starts with a generated-from header. Then remove what the direction
rules out from the components it names (a card shadow, a radius),
inside `src/components/ui`, never per feature.
8. Full setup only: `docs/design/components.md` from
`templates/components.md` (each entry names its `src/components/ui`
component and allowed variants; a missing need becomes a variant
there; `- States:` stays one comma list on one line). Then
`system_page.py tokens-css`, `build` and `check` (paths in the
script's help; `build --fonts-css <file>` links the product's own
`@font-face` stylesheet, and `--google-fonts` is only for a product
that loads its faces from Google); `check` must exit 0; open the page
in both themes. On react-shadcn the binding in `globals.css` or
`index.css` is written by hand from `tokens.json` (no generator writes
shadcn's names yet); compare its roles with `tokens.css` after each
change.
Write `docs/design/DESIGN.md` from `templates/DESIGN.md` as the
system's guide, linking to the direction; when the repo has no root
`DESIGN.md`, add a relative symlink to the guide so gstack finds it.
