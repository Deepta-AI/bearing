# Stack bindings: from tokens.json to code

`docs/design/tokens.json` is the only file a person edits. Each stack
gets one generated file. The generated file carries a header line
`generated from docs/design/tokens.json v<version>; do not edit` and is
regenerated whenever `tokens.json` changes. Every name below is derived
from the token path, so a role called `surface-raised` is
`--color-surface-raised` on the web, `surfaceRaised` in TypeScript and
Kotlin, and `.surfaceRaised` in Swift.

## A worked tokens.json fragment

```json
{
  "meta": { "name": "Ledger", "version": 1, "source": "DESIGN.md",
            "memorable": "numbers you can trust at a glance" },
  "color": {
    "primitives": {
      "neutral": { "0": { "oklch": "oklch(99% 0.004 250)", "hex": "#fafcfe" },
                   "100": { "oklch": "oklch(95% 0.005 250)", "hex": "#eceff2" },
                   "300": { "oklch": "oklch(84% 0.008 250)", "hex": "#c7cbd0" },
                   "500": { "oklch": "oklch(62% 0.014 250)", "hex": "#80878e" },
                   "700": { "oklch": "oklch(42% 0.013 250)", "hex": "#484e54" },
                   "900": { "oklch": "oklch(24% 0.008 250)", "hex": "#1c2023" },
                   "1000": { "oklch": "oklch(16% 0.006 250)", "hex": "#0b0d10" } },
      "accent": { "0": { "oklch": "oklch(97% 0.010 250)", "hex": "#f0f6fc" },
                  "100": { "oklch": "oklch(92% 0.037 250)", "hex": "#d3e7fd" },
                  "300": { "oklch": "oklch(78% 0.093 250)", "hex": "#89bcf1" },
                  "500": { "oklch": "oklch(52% 0.145 250)", "hex": "#066bb8" },
                  "700": { "oklch": "oklch(44% 0.123 250)", "hex": "#035493" },
                  "900": { "oklch": "oklch(30% 0.087 250)", "hex": "#002f57" },
                  "1000": { "oklch": "oklch(20% 0.053 250)", "hex": "#01172d" } }
    },
    "roles": {
      "light": { "bg": "neutral.0", "surface": "neutral.0", "surface-raised": "neutral.0",
                 "text": "neutral.900", "text-muted": "neutral.700", "accent": "accent.500",
                 "on-accent": "neutral.0", "focus": "accent.500" },
      "dark":  { "bg": "neutral.1000", "surface": "neutral.900", "surface-raised": "neutral.700",
                 "text": "neutral.0", "text-muted": "neutral.300", "accent": "accent.300",
                 "on-accent": "neutral.1000", "focus": "accent.300" }
    }
  },
  "space": { "base": 8, "half": 4,
             "scale": { "0": 0, "1": 4, "2": 8, "3": 16, "4": 24, "5": 32, "6": 48, "7": 64, "8": 96 } },
  "radius": { "control": 6, "container": 12, "overlay": 16, "full": 9999 },
  "motion": { "duration": { "instant": 80, "fast": 150, "base": 240, "slow": 400, "deliberate": 700 },
              "easing": { "standard": "cubic-bezier(0.2, 0, 0, 1)", "enter": "cubic-bezier(0, 0, 0.2, 1)",
                          "exit": "cubic-bezier(0.4, 0, 1, 1)",
                          "spring": { "stiffness": 300, "damping": 30, "mass": 1 } },
              "stagger": 40 }
}
```

The fragment omits roles that the schema requires; the schema is the
list. Neutral steps carry a little of the accent hue (chroma 0.004 to
0.016) so grey surfaces belong to the same product as the accent.

## Deriving colours

Pick the accent hue from the direction. Build each scale by holding hue
and varying lightness in oklch, with chroma peaking around L 55 to 65
and falling towards both ends. Dark mode is designed: surfaces go
`1000, 900, 700` (lighter as they rise), the accent moves one step
lighter, chroma drops 10 to 20 percent, and text is `0` not pure white.
Never invert the light roles. Every text-on-surface pair must reach
4.5:1 (`references/contrast.md` in `themes` has the pairs).

Hex fallbacks are computed, never guessed:

```bash
python3 - <<'EOF'
import math
def oklch_to_hex(L, C, h):
    a, b = C * math.cos(math.radians(h)), C * math.sin(math.radians(h))
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    lin = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
           -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
           -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    def g(c):
        c = min(max(c, 0.0), 1.0)
        return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return "#" + "".join(f"{round(g(c) * 255):02x}" for c in lin)
print(oklch_to_hex(0.52, 0.145, 250))  # #066bb8
EOF
```

A value that clips (any channel outside 0..1 before clamping) is out of
sRGB gamut; lower the chroma until it does not.

## React with shadcn/ui (the default stack)

First read what the repo already consumes; the binding writes values in
that form, never in the form this reference happens to show.

| The repo has | Variables hold | Dark selector |
| --- | --- | --- |
| Tailwind 4: `@theme inline` in `src/index.css`, no `tailwind.config.*` colours | full colours (`#1b7a4c`, or oklch behind `@supports`) | `@custom-variant dark` in index.css |
| Tailwind 3: `tailwind.config.*` colours written `hsl(var(--x))` or `hsl(var(--x) / <alpha-value>)` | HSL channels only: `152 64% 30%`, no `hsl()`, no hex, no oklch | `darkMode` in the config |
| Tailwind 3 config colours written `var(--x)` | full colours; opacity modifiers (`bg-primary/90`) stop working | `darkMode` in the config |

A value in the wrong form is silently invalid: `hsl(var(--primary))` with
`--primary: #1b7a4c` or `oklch(...)` computes to nothing, and every colour
using it disappears with no build error.

File: `src/styles/tokens.css` (or `web/src/styles/tokens.css`), imported
from `src/index.css` before the Tailwind layers (Tailwind 4: after
`@import "tailwindcss"` and before `@theme inline`). It writes the
variables shadcn/ui components read, from the roles in `tokens.json`, and
nothing else: the template's `:root` and `.dark` blocks in `index.css` are
removed so there is one source. A second set of `--color-*` variables
beside these leaves every shadcn component on the neutral defaults.

| shadcn variable | Token role (light and dark) |
| --- | --- |
| `--background` | `bg` |
| `--foreground` | `text` |
| `--card`, `--card-foreground` | `surface`, `text` |
| `--popover`, `--popover-foreground` | `surface-raised`, `text` |
| `--primary`, `--primary-foreground` | `accent`, `on-accent` |
| `--secondary`, `--secondary-foreground` | `bg-subtle`, `text` |
| `--muted`, `--muted-foreground` | `bg-subtle`, `text-muted` |
| `--accent`, `--accent-foreground` | `accent-subtle`, `text` |
| `--destructive`, `--destructive-foreground` | `danger`, `on-danger` |
| `--border`, `--input`, `--ring` | `border`, `border-strong`, `focus` |
| `--chart-1` to `--chart-5` | `accent`, `info`, `success`, `warning`, `danger` |
| `--sidebar`, `--sidebar-foreground` | `bg-subtle`, `text` |
| `--sidebar-primary`, `--sidebar-primary-foreground` | `accent`, `on-accent` |
| `--sidebar-accent`, `--sidebar-accent-foreground` | `accent-subtle`, `text` |
| `--sidebar-border`, `--sidebar-ring` | `border`, `focus` |
| `--radius` | `radius.container` |
| `--font-sans`, `--font-mono` | `font.body`, `font.mono` (with fallbacks) |

Write the variables the repo's components and config reference;
`--sidebar-*` and `--chart-*` only when something reads them.

Tailwind 3 (`hsl(var(--x))`):

```css
/* generated from docs/design/tokens.json v1; do not edit */
:root {
  --background: 40 20% 98%;
  --foreground: 30 10% 11%;
  --primary: 152 64% 30%;
  --primary-foreground: 0 0% 100%;
  /* every row of the table above, as H S% L% channels */
  --radius: 0.5rem;
  color-scheme: light;
}
[data-theme="dark"] { /* the designed dark roles, never an inversion */ color-scheme: dark; }
```

with `darkMode: ["selector", '[data-theme="dark"]']` in `tailwind.config.js`
(Tailwind 3.4.1 and later; earlier 3.x: `["class", '[data-theme="dark"]']`)
when the toggle sets `data-theme`, or `darkMode: "class"` and a `.dark`
block when it sets the class. The CSS selector, the config and the code
that flips the theme name the same thing; name all three in the report.

Channels are rounded, so contrast is measured on the rounded value that
ships, not on the hex it came from:

```python
import colorsys
def channels(hexv):
    r, g, b = (int(hexv[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return f"{h * 360:.0f} {s * 100:.1f}% {l * 100:.1f}%"
print(channels("#1b7a4c"))
```

Tailwind 4 (`@theme inline`): the same table as full colours, hex in the
theme blocks, oklch only in an `@supports (color: oklch(0 0 0))` block
when the browser floor allows it (see Colour and the browser floor), and
`--font-sans: var(--font-sans); --font-mono: var(--font-mono);` plus the
type sizes (`--text-xs` to `--text-2xl` with their
`--text-*--line-height` pairs) added to the `@theme inline` block.

`contrast.py` measures the same roles in both modes. Add the pairs the
components actually render that the role table lacks: a hover fill such
as `bg-primary/90` composited over the page it sits on, a link colour on
the card as well as the page, the focus ring against both.

## Colour and the browser floor

Read the floor before choosing a colour syntax: `browserslist` in
`package.json` or `.browserslistrc`, an ADR or README naming supported
browsers, a Vite `build.target`. Safari gained `oklch()` and `color-mix()`
in 15.4 and `lab()` in 15; Chrome in 111. A custom property is not
validated until use, so `--x: #hex; --x: oklch(...)` keeps the oklch value
and an older browser gets no colour at all. The fallback that works:

```css
:root { --color-accent: #066bb8; }
@supports (color: oklch(0 0 0)) { :root { --color-accent: oklch(52% 0.145 250); } }
```

With a floor below the oklch versions, or no known floor, ship sRGB (hex or
HSL) and keep oklch in `tokens.json` as the derivation.

## Web: CSS custom properties plus Tailwind v4 `@theme` (other web stacks)

File: `src/styles/tokens.css`, imported first from `src/index.css`.
Colours are hex in the theme blocks; oklch, when the floor allows it,
goes in an `@supports` block after them (Colour and the browser floor).

```css
/* generated from docs/design/tokens.json v1; do not edit */
:root {
  --color-bg: #fafcfe;
  --color-text: #1c2023;
  --color-accent: #066bb8;
  --font-display: "Fraunces", Georgia, serif;
  --font-body: "Source Sans 3", "Segoe UI", system-ui, sans-serif;
  --text-body: 16px; --leading-body: 1.5; --tracking-body: 0;
  --space-1: 4px; --space-2: 8px; --space-3: 16px; --space-4: 24px;
  --radius-control: 6px; --radius-container: 12px; --radius-overlay: 16px;
  --elevation-1: 0 1px 2px rgb(0 0 0 / 0.08);
  --duration-base: 240ms; --ease-enter: cubic-bezier(0, 0, 0.2, 1);
  --z-modal: 40; --focus-width: 2px; --focus-offset: 2px;
  color-scheme: light;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme]) { /* dark roles */ color-scheme: dark; } }
:root[data-theme="dark"] { /* dark roles */ color-scheme: dark; }
@supports (color: oklch(0 0 0)) { :root { --color-bg: oklch(99% 0.004 250); /* ... */ } }
:focus-visible { outline: var(--focus-width) solid var(--color-focus); outline-offset: var(--focus-offset); }
@media (prefers-reduced-motion: reduce) { :root { --duration-instant: 0ms; --duration-fast: 0ms; --duration-base: 0ms; --duration-slow: 0ms; --duration-deliberate: 0ms; } }

@theme inline {
  --color-bg: var(--color-bg); --color-text: var(--color-text); --color-accent: var(--color-accent);
  --font-display: var(--font-display); --font-body: var(--font-body);
  --text-body: var(--text-body); --spacing-1: var(--space-1); --spacing-2: var(--space-2);
  --radius-control: var(--radius-control); --shadow-1: var(--elevation-1);
  --ease-enter: var(--ease-enter);
}
```

`@theme inline` makes `bg-bg`, `text-accent`, `p-3`, `rounded-control`
and `shadow-1` real utilities that follow the cascade, so `data-theme`
switching needs no rebuild. Tailwind's default palette and spacing are
disabled with `--color-*: initial; --spacing: initial;` at the top of
the block so an off-scale class does not compile. Elevation utilities
are named `shadow-1..3` only; `shadow-sm`, `shadow-md` do not exist.

## React Native: `theme.ts` with NativeWind

File: `src/theme/theme.ts`. Hex only (React Native has no oklch). The
object is typed, frozen and read through `useTheme()` from a provider;
NativeWind reads the same object in `tailwind.config.js`.

```ts
// generated from docs/design/tokens.json v1; do not edit
export const primitives = { neutral: { 0: "#fafcfe", 900: "#1c2023" }, accent: { 500: "#066bb8" } } as const;
export const roles = {
  light: { bg: primitives.neutral[0], text: primitives.neutral[900], accent: primitives.accent[500] },
  dark: { bg: "#0b0d10", text: "#fafcfe", accent: "#89bcf1" },
} as const;
export const space = { 0: 0, 1: 4, 2: 8, 3: 16, 4: 24, 5: 32, 6: 48, 7: 64 } as const;
export const radius = { control: 6, container: 12, overlay: 16, full: 9999 } as const;
export const font = { display: "Fraunces", body: "SourceSans3", mono: "JetBrainsMono" } as const;
export const text = { label: 13, body: 16, title: 22, display: 32 } as const;
export const duration = { instant: 80, fast: 150, base: 240, slow: 400, deliberate: 700 } as const;
export const elevation = { 0: {}, 1: { shadowOpacity: 0.08, shadowRadius: 2, elevation: 1 } } as const;
export type Roles = typeof roles.light;
```

`tailwind.config.js`: `theme: { colors: roles.light, spacing: space, borderRadius: radius, fontSize: text }`
with `darkMode: "class"`; the provider toggles the `dark` class and
exposes `roles[mode]` for `StyleSheet` code. Font files are loaded
with `expo-font` under the names in `font`.

## Android: Compose `Theme.kt`

Files under `ui/theme/`: `Color.kt` (primitives as `Color(0xFF066BB8)`),
`Type.kt` (the type roles as `TextStyle`), `Shape.kt`, `Theme.kt`.
Roles map onto Material 3 `ColorScheme` slots, and the roles Material
lacks live in a `LocalRoles` composition local.

```kotlin
// generated from docs/design/tokens.json v1; do not edit
val LightColors = lightColorScheme(
    background = Neutral0, surface = Neutral0, surfaceContainer = Neutral100,
    onBackground = Neutral900, onSurface = Neutral900, onSurfaceVariant = Neutral700,
    primary = Accent500, onPrimary = Neutral0, outline = Neutral300, error = Danger500,
)
val DarkColors = darkColorScheme(background = Neutral1000, surface = Neutral900, primary = Accent300, /* ... */)
data class Roles(val focus: Color, val selection: Color, val accentSubtle: Color, val link: Color)
val LocalRoles = staticCompositionLocalOf<Roles> { error("AppTheme missing") }
object Space { val s1 = 4.dp; val s2 = 8.dp; val s3 = 16.dp; val s4 = 24.dp; val s5 = 32.dp }
object Radius { val control = 6.dp; val container = 12.dp; val overlay = 16.dp }
object Duration { const val Instant = 80; const val Fast = 150; const val Base = 240; const val Slow = 400 }

@Composable
fun AppTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalRoles provides if (dark) DarkRoles else LightRoles) {
        MaterialTheme(colorScheme = if (dark) DarkColors else LightColors, typography = AppTypography, shapes = AppShapes, content = content)
    }
}
```

Dynamic colour (`dynamicLightColorScheme`) is off unless the direction
asks for it; it replaces the derived palette with the wallpaper's.
Elevation: `tonalElevation` is 0 everywhere; `shadowElevation` only on
`Button`, `Card(onClick)` and overlays, per the elevation rule.

## iOS: SwiftUI `Theme.swift`

File: `App/Theme/Theme.swift`. Colours as `Color(.sRGB, red:green:blue:)`
from the hex, or as asset-catalog colour sets with Any and Dark
appearances when the app already uses the catalog. Roles are a struct
in the environment so a theme swap is one assignment.

```swift
// generated from docs/design/tokens.json v1; do not edit
struct Roles { let bg, surface, surfaceRaised, text, textMuted, accent, onAccent, focus: Color }
extension Roles {
    static let light = Roles(bg: Color(hex: 0xFAFCFE), surface: Color(hex: 0xFAFCFE), surfaceRaised: Color(hex: 0xFAFCFE),
                             text: Color(hex: 0x1C2023), textMuted: Color(hex: 0x484E54), accent: Color(hex: 0x066BB8),
                             onAccent: Color(hex: 0xFAFCFE), focus: Color(hex: 0x066BB8))
    static let dark = Roles(/* designed dark roles */)
}
extension Color { init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255) } }
extension Font {
    static func display(_ size: CGFloat = 32) -> Font { .custom("Fraunces", size: size, relativeTo: .largeTitle) }
    static let body = Font.custom("SourceSans3-Regular", size: 16, relativeTo: .body)
    static let label = Font.custom("SourceSans3-Regular", size: 13, relativeTo: .footnote)
}
enum Space { static let s1: CGFloat = 4, s2 = 8, s3 = 16, s4 = 24, s5 = 32 }
enum Radius { static let control: CGFloat = 6, container = 12, overlay = 16 }
enum Duration { static let instant = 0.08, fast = 0.15, base = 0.24, slow = 0.4, deliberate = 0.7 }
private struct RolesKey: EnvironmentKey { static let defaultValue = Roles.light }
extension EnvironmentValues { var roles: Roles { get { self[RolesKey.self] } set { self[RolesKey.self] = newValue } } }
```

`relativeTo:` keeps Dynamic Type working; a fixed `size:` without it
is a finding. `AccentColor` in the asset catalog is set to the accent
role so system controls match.

## What the lint reads

`design-lint.sh` takes its scales from `DESIGN_SPACE_SCALE` and
`DESIGN_FONT_SCALE`, else `space.scale` and `font.sizes` in `tokens.json`,
else the `--space-*` and `--font-size-*` (or `--text-*`) values of the
token CSS file, and prints which. Generated theme files and token CSS are
where literals are defined, so they are skipped; add any other generated
file to `DESIGN_LINT_EXCLUDE`.
