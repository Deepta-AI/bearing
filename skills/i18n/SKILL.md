---
name: i18n
description: 'Internationalises the app: string catalogs per platform, ICU plurals, locale formatting, fallbacks, an RTL check, a missing-key count. Use when asked to "add a language", "translate the app", "add i18n" or "support RTL".'
argument-hint: "[add <locale>] [--check-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(make:*), Bash(python3 -c:*), Bash(node:*), Bash(pnpm test:*), Bash(./gradlew test:*), Bash(swift test:*)
---

# i18n

A user-facing string is data with a key. The key lives in one catalog
per platform, the text lives in one file per locale, and the layout
does not assume the text's length or direction.

## Inputs

- stack: detected from `package.json` with `react` (react-web) or `expo`
  (react-native), `build.gradle.kts` (android), `Package.swift` or
  `*.xcodeproj` (ios); more than one match: ask one question; none, or
  only `go.mod` or `pyproject.toml`: stop with "no client stack; services
  return `messageKey` and the client translates".
- source files: the stack's source tree (`src/`, `app/`, `app/src/main`,
  `Sources/`); zero files: ask once for the path; still zero: stop with
  "0 source files under <path>; name the source directory".
- checklist: this skill's own `references/i18n-checklist.md`.
- catalog: the existing one if any (`src/locales/`, `res/values/`,
  `Localizable.xcstrings`); if absent, created in step 3.
- default locale: the existing catalog's; if absent, `en`.
- `make i18n-check` and `make check`: added to the Makefile when it
  exists; if absent, the check script is still written and its command
  printed, and the report says the Makefile comes from `new-repo`
  or `onboard-repo`; the gate is then the stack's native test command.

## Steps

1. Resolve the stack and the source files as in Inputs. Read
   `references/i18n-checklist.md` once.
2. Count the hard-coded strings. Grep, per stack, for text a user would
   read: JSX text nodes and `placeholder=`, `title=`, `aria-label=`
   literals (web, RN); `Text("`, `label = "`, `contentDescription = "`
   in Compose and `android:text="` literals in XML (Android); `Text("`,
   `Label("`, `Button("`, `.navigationTitle("` in SwiftUI (iOS).
   Exclude test files, storybook and fixtures. Print the count before
   any change.
3. Set up the catalog if missing: `src/locales/<locale>/<ns>.json` with
   react-i18next and ICU (`i18next-icu`) on web and RN; `res/values/
   strings.xml` plus `values-<locale>/` with `<plurals>` on Android;
   `Localizable.xcstrings` with `String(localized:)` on iOS. One
   default locale (`en`), keys dotted by feature (`invoice.list.empty`),
   never the English text as the key.
4. Move every string found into the catalog with a key and replace the
   literal with the lookup. Plurals and gender through ICU select and
   plural (`{count, plural, one {# invoice} other {# invoices}}`) on
   web and RN; `<plurals>` on Android; `^[count](inflect: true)` or a
   plural variation in the String Catalog on iOS. Dates, numbers and
   currencies through `Intl.DateTimeFormat`, `Intl.NumberFormat`
   (web, RN with the Hermes Intl), `java.text.NumberFormat` and
   `DateUtils` (Android), `FormatStyle` (iOS). No hand-built formats.
5. Locale resolution: device locale, then the user's saved choice, then
   the fallback chain (`hi-IN` to `hi` to `en`). One function per
   stack returns it; the catalog loader and the formatters read it.
6. RTL: enable `I18nManager` (RN) or `dir` on `html` (web),
   `android:supportsRtl="true"` and start and end instead of left and
   right (Android), leading and trailing (iOS). Render the main screens
   with a pseudo-locale (`ar` or the platform's pseudo RTL) and list
   any layout that breaks.
7. `i18n-check`: compares every locale's keys against the default
   locale, counts missing and unused keys, fails when missing is above
   zero or when zero keys were compared, and prints
   `i18n-check: N keys, M locales, K missing, U unused`. Web and RN: a
   small script in `scripts/i18n-check.mjs`; Android: `lint` with
   `MissingTranslation` as error; iOS: `xcstringstool` or a script over
   the catalog JSON. Wire it into the Makefile as `i18n-check` under
   `check`, or print the command as in Inputs.
8. `add <locale>`: create the locale file with every key and the
   default text marked `TODO(<locale>)`, run `i18n-check` (which must
   fail on the TODO count), and print the count to translate.
9. Run the gate and print the contract.

## Output contract

```
## i18n: <stack> (<N> source files scanned)
Catalog: <path> (<library>); default locale: en; locales: <list>
Hard-coded strings: before N, after M (<files still holding them>)
Plurals through ICU or platform plurals: N messages
Formatters: Intl | NumberFormat | FormatStyle in <module>
RTL: checked <N> screens with <pseudo-locale>; breaks: <list or none>
i18n-check: N keys, M locales, K missing, U unused (make target | script only)
gate: make check | <native command>: passed | failed (<target>)
```

## Gotchas

- Never concatenate translated fragments; word order differs by
  language. One message with placeholders.
- A key named after its English text (`"Save changes"`) breaks the
  moment the English changes. Keys name the place and the meaning.
- `toLocaleString()` without a locale argument uses the runtime's
  locale, not the user's. Always pass the resolved locale.
- Indian numbering (`12,34,567`) comes from `en-IN`, not from a custom
  formatter. Currency is `INR` with `Intl.NumberFormat`, never a `Rs`
  prefix in the string.
- Android `values-b+sr+Latn` style qualifiers for script variants;
  `values-hi` alone is fine for Hindi.
- iOS String Catalog entries with no translation fall back to the
  development language silently; `i18n-check` is the only thing that
  notices.
- Pseudo-locale testing (longer text, RTL) finds truncation before a
  translator does. A fixed-width label is a finding.
