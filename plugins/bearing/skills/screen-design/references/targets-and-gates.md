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
  at all fails (`0 actions`); all actions client-only passes.
- Check: `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/states_check.py" --needs <file> --flows <flows file>`
  fails on a screen with no entry, an action with no outcome, an outcome
  without a status or code, a status other than `exists` or `new`, a
  loading, empty or error state with no server condition, an action id
  used twice, a `none:` with no reason, no action in the whole file, and
  zero screens or a missing file.
  It prints one counts line starting `data-needs:` with the screens,
  fields, actions (exists and new), outcomes, states and problems. Without
  a flows file there is no
  inventory to check against, so the step is skipped and said.
- `data-model` and `openapi-spec` read this file (fields to columns,
  actions to operations, outcomes to documented responses).
