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
