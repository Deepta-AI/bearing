# screen-design: targets and gates

Read when choosing the target stack, locating the gallery files, or running the gates (Inputs).

- Target: `--framework`; else the ui stack in
  `.bearing/state/autopilot.json`; else detected: `react-native` or `expo`
  in package.json is `react-native`; `pubspec.yaml` with a `flutter:`
  dependency is `flutter`; `androidx.compose` in a gradle file is
  `compose`; `Package.swift` or an `.xcodeproj` is `swiftui`; a React web
  app, or no UI code yet, is `react-shadcn`. Only `react-shadcn` builds
  screens as code, and only when the gallery can run (step 8 of the
  reconciliation in references/reconcile-sources.md); every other target builds the HTML bundle.
- Gallery files (react-shadcn): `src/design/screen.ts`, `Gallery.tsx`,
  `registry.ts`; absent in an older app: copy them from
  `templates/skeleton/src/design/` in the `bearing-apps:react` skill
  (`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-kit-paths" --skill react` prints
  its directory, or names the plugin to install) and say so; when that
  plugin is absent, use the HTML bundle.
- Gates, Python 3 only: `scripts/gallery_check.py` (react-shadcn: every
  inventory screen has a `*.screen.tsx`, every state is a key of its
  `states`, no raw element where a component exists);
  `scripts/states_check.py` (HTML: every inventory state has a panel and a
  control that reaches it, no unfilled placeholder; reads a repo's own
  `data-target` or `#state=` links and treats `no slots` as `no-slots`);
  `scripts/bundle.py` (manifest audit, gallery, check);
  `${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py`
  (widths and themes);
  `${CLAUDE_PLUGIN_ROOT}/skills/accessibility/scripts/contrast.py`
  (measured WCAG ratios).

## Data needs

Read when writing `docs/design/screens/<feature>/data-needs.md` (SKILL.md,
Data needs step).

- Content, per screen of the flows inventory: the fields shown (name, type,
  where they come from), the actions (what the user does and what must
  happen on the server, with every outcome as `<status> <code>`), and the
  server condition behind each loading, empty and error state, including
  each error code the flows' error rows name. Table shape:
  `templates/data-needs.md`.
- Existing API: read the contract as the reconciliation does (code routes,
  the API client and its types, an existing OpenAPI file) and mark each
  field and action `exists` or `new`. Greenfield: every need is `new`.
- A client-only action writes `none: <reason>` in Server and needs no
  outcome; a screen that needs nothing writes a `none: <reason>` row per
  table, so its entry is deliberate. A feature whose file holds no action
  at all fails (`0 actions`); all actions client-only passes only on
  screens that show no server data.
- A screen that shows server data (a `server` field, or a state with a
  server condition) lists the read that loads it as an action, marked
  `exists` when the API already has it (A-03, Load members, list the
  members, `200 members`, exists): the API is derived from the actions,
  so a read left out has no operation.
- Ids are unique across the product, not only the file: number a new
  feature's `F-` and `A-` ids after the highest in use in every other
  `docs/design/screens/*/data-needs.md` (the members feature ends at A-03,
  so billing starts at A-04).
- Check: `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/states_check.py" --needs <file> --flows <flows file>`
  fails on a screen with no entry, an action with no outcome, an outcome
  without a status or code, a status other than `exists` or `new`, a
  loading, empty or error state with no server condition, a screen with
  server data and no server action, an action id used twice, a `none:`
  with no reason, no action in the whole file, and zero screens or a
  missing file. `api_doc.py needs` and `model_check.py --needs` read every
  feature's file at once and fail on an id in two files, naming both.
  It prints one counts line starting `data-needs:` with the screens,
  fields, actions (exists and new), outcomes, states and problems. Without
  a flows file there is no
  inventory to check against, so the step is skipped and said.
- Format for readers (the grammar other scripts rely on):
  - An outcome is a 3-digit status, then a code (`409 already_member`);
    outcomes are separated by `;` or a newline; backticks and asterisks are
    stripped. `2xx` and `default` are rejected.
  - Server `none: <reason>` marks a client-only action; its Outcomes and
    Status may then be blank.
  - A row whose first cell is `none:` is a placeholder, not an action, field
    or state.
  - Action ids (`A-<digits>`) and field ids (`F-<digits>`) are unique
    across all `docs/design/screens/*/data-needs.md` files of the product;
    an action id is the only join key from an action to an API operation
    (`x-data-needs` is one namespace), a field id the join to a dictionary
    Why. The Action and Server columns are free text.
  - A screen with a `server` field or a non-empty server condition has at
    least one action whose Server is not `none:` (its read).
  - Source and Status are matched case-insensitively.
  - The reference parser is `parse_needs(text)` and `outcomes(cell)` in
    `scripts/states_check.py`; other scripts load it by path.
- `data-model` and `openapi-spec` read this file (fields to columns,
  actions to operations, outcomes to documented responses).
