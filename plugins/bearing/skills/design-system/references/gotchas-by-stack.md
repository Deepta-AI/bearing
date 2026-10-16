# design-system: gotchas by stack

Read when: the stack is Tailwind 4, React Native, Android or iOS.

- `hsl(var(--x))` in a Tailwind 3 config and a hex in `--x` compile
  without error and render nothing. Grep the config before writing a
  value.
- Opacity modifiers (`bg-primary/90`) are new colours: a 90 percent
  primary over white is lighter than the token and can drop a passing
  label below 4.5:1. Measure the composite, or give hover its own token.
- `@theme` without `inline` snapshots values at build time and breaks
  runtime theme switching; `inline` keeps the cascade.
- Tailwind's default palette stays reachable unless `--color-*: initial`
  (v4) or `theme.colors` replaced (v3); that is a scope decision, so it
  is proposed, not done, when the request did not ask.
- React Native has no oklch and no CSS cascade: the provider supplies
  `roles[mode]` for `StyleSheet` code as well as the class.
- Material 3 dynamic colour replaces the derived palette with the
  wallpaper's; leave it off unless the direction asks.
- A SwiftUI `Font.custom` without `relativeTo:` disables Dynamic Type.
