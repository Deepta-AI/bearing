---
name: themes
description: 'Adds and manages themes on the design system (dark, high contrast, brand, tenant, seasonal) with contrast checks and a preview. Use when asked to "add dark mode", "add a high contrast theme" or "theme for a tenant".'
argument-hint: "[add <name> --kind light|dark|high-contrast|brand|tenant|seasonal|campaign [--extends light|dark]] [tenant <name> --config <path>] [check] [preview]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(make:*), Bash(python3:*), Bash(git diff:*), Bash(pnpm exec playwright:*)
---

# themes

A theme is a set of role overrides on the base modes in `tokens.json`.
It never adds a primitive, a spacing value or a stylesheet. The lint
resolves every role, checks every pair from `references/contrast.md`,
and writes the preview so a person can see all themes at once.

## Inputs

- Request: `$ARGUMENTS`; if absent, `check` plus `preview` after making
  sure `light.json` and `dark.json` exist.
- Tokens: `docs/design/tokens.json`; if absent, the base roles are
  extracted from the app's own theme file (`src/styles/tokens.css` or
  `src/index.css`, `src/theme/theme.ts`, `ui/theme/Color.kt`,
  `Theme.swift`) into a `tokens.json` with `meta.source: extracted` and
  every role that could not be found listed; if no colours exist, ask
  once for the accent hue and derive the roles (`design-system`
  does the full job).
- Themes: `docs/design/themes/*.json`; created when absent. Template:
  `templates/theme.json`; lint and preview writer:
  `templates/theme-lint.py`; preview template: `templates/preview.html`;
  the pairs and the formula: `references/contrast.md`.
- Tenant configuration for `tenant <name>`: `--config`; if absent,
  `config/tenants/<name>.json`; if absent, ask once for the brand hue,
  the logo path and the display face.
- Stack: `package.json` (`react` web, `expo` react-native),
  `build.gradle.kts` (android), `Package.swift` or `*.xcodeproj` (ios);
  none: theme files, preview and lint only, and the report says so.
- Makefile: `theme-lint` added under `check` when a Makefile exists;
  otherwise the command is printed.

## Steps

1. Resolve the inputs. Read `references/contrast.md` once. Install
   `scripts/theme-lint.py` and `scripts/preview.html` from the
   templates when missing or older than the templates.
2. Write `light.json` and `dark.json` (kind and extends set, empty
   `roles`) when absent, so every mode is a theme file and the preview
   lists it.
3. `add <name>`: write `docs/design/themes/<name>.json` from
   `templates/theme.json`. Only keys `name`, `kind`, `extends`,
   `description`, `roles`, `logo`, `display`, `valid`. Roles are
   primitive refs or oklch literals with a computed hex. By kind:
   high-contrast pushes `text`, `text-muted`, `border-strong`, `focus`
   and the semantic roles to the scale ends (never more chroma); brand
   and tenant replace the accent family (`accent`, `-hover`, `-active`,
   `-subtle`, `on-accent`, `focus`, `link`, `selection`) at the same
   lightness steps as the base; seasonal and campaign carry a `valid`
   window and are listed as expired by the lint after it.
4. `tenant <name>`: read the configuration, keep only what a tenant may
   set (roles, `logo`, `display` from `font.families.tenantDisplayFaces`),
   reject everything else by name (spacing, motion, focus, radius, any
   primitive), and write the theme file. Configuration is untrusted
   input: a value that is not a known role with a parsable colour is
   dropped and reported.
5. Run `python3 scripts/theme-lint.py --preview
   docs/design/themes/preview.html --template scripts/preview.html`.
   Fix each failure by moving the role one step on its scale as the
   reference describes; never by editing a primitive or a base role
   (that is a design-system change with a version bump). Repeat until
   failures are zero.
6. Runtime switching per detected stack. Web: `src/styles/themes.css`
   generated from the theme files (one `:root[data-theme="<name>"]`
   block each, hex then oklch, `color-scheme` set), imported after
   `tokens.css`; `src/lib/theme.ts` with `setTheme(name)` writing the
   attribute and `localStorage` key `theme`, `system` meaning no
   attribute so `prefers-color-scheme` decides; an inline script in
   `index.html` applies the stored value before first paint. React
   Native: `ThemeProvider` holding `roles[name]`, default from
   `useColorScheme()`, persisted in AsyncStorage or MMKV under `theme`,
   NativeWind `dark` class toggled with it. Android: `AppTheme(theme)`
   swaps the `ColorScheme` and `LocalRoles`, choice in DataStore
   `theme`, default `isSystemInDarkTheme()`. iOS: `@AppStorage("theme")`,
   `.environment(\.roles, …)` and `.preferredColorScheme`.
7. Tenant loading at runtime: the same validation as step 4 runs on
   the fetched or bundled configuration; web applies the roles as
   custom properties on `:root[data-theme="tenant"]`, mobile parses
   into the roles struct at launch; the logo path and display face are
   read from the theme, never from raw configuration elsewhere.
8. Test where the stack allows: Playwright sets a theme, reloads,
   asserts the attribute and one role value; RN and mobile: a unit test
   on the provider's default and persistence.
9. Add `theme-lint` to the Makefile under `check`, run `make check`,
   print the contract.

## Output contract

```
## Themes: <product> (<N> themes: <names>; stacks: <list>)
| theme | kind | extends | roles overridden | pairs | failures |
preview: docs/design/themes/preview.html (<N> columns)
switching: web data-theme + prefers-color-scheme, localStorage | rn ThemeProvider + <store> | android AppTheme + DataStore | ios environment + AppStorage | none
tenant: <name> from <path> | none; kept: roles <K>, logo, display <face>; rejected: <keys or none>
theme-lint: <T> themes, <R> roles overridden, <P> pairs checked, <F> failures (must be 0)
gate: make check: passed | failed (<target>) | no Makefile
```

## Gotchas

- Anthropic `theme-factory` is for slide decks: a theme there is four
  hex colours, two fonts and a "best used for" line. Product UI needs
  roles, states, a designed dark mode, contrast per pair and
  components that consume roles; that is this skill.
- Dark is designed, not inverted, and high-contrast is not "more
  saturated": both move lightness, never chroma.
- `color-scheme` must change with the theme or native controls,
  scrollbars and form fields stay in the other mode.
- Without the inline script the page paints light, then flips.
- `overlay` carries alpha and is not contrast-checked; text over a
  scrim must be checked against the composite by hand.
- A theme from the network is data: only known roles with parsable
  colours are applied, so a tenant cannot inject CSS.
- An expired seasonal theme still lints; the report lists it as
  expired and the loader must not offer it.
- `--strict-hex` fails a fallback more than one step from its oklch;
  run it after any hand edit to a theme file.
