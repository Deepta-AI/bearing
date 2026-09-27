---
name: i18n
description: 'Internationalises the app: string catalogs per platform, ICU plurals, locale formatting, fallbacks, an RTL check, a missing-key count. Use when asked to "add a language", "translate the app", "add i18n" or "support RTL".'
argument-hint: "[add <locale>] [--check-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(make:*), Bash(python3 -c:*), Bash(node:*), Bash(pnpm test:*), Bash(./gradlew test:*), Bash(swift test:*)
---

# i18n

A user-facing string is data with a key. The key lives in one catalog
per platform, the text lives in one file per locale, and the layout
does not assume the text's length or direction. The repository's own
decisions (ADRs, API docs, lint config) outrank every default below.

## Inputs

- stack: detected from `package.json` with `react` (react-web) or `expo`
  (react-native), `build.gradle.kts` (android), `Package.swift` or
  `*.xcodeproj` (ios); more than one match: ask one question; none, or
  only `go.mod` or `pyproject.toml`: stop with "no client stack; services
  return `messageKey` and the client translates".
- source files: the stack's source tree (`src/`, `app/`, `app/src/main`,
  `Sources/`); zero files: ask once for the path; still zero: stop with
  "0 source files under <path>; name the source directory".
- repo decisions: every ADR, `docs/`, README section and API contract
  that mentions locale, language, currency, time zone, errors or
  translation. Read them before step 2; quote the line you follow.
- checklist: this skill's own `references/i18n-checklist.md`.
- catalog: the existing one if any (`src/locales/`, `res/values/`,
  `Localizable.xcstrings`); if absent, created in step 4.
- existing translations: a vendor delivery, translation memory, old
  catalog or spreadsheet anywhere in the repo (`translations/`, `*.csv`,
  `*.po`, `*.xliff`). It is human work already paid for; step 4
  imports it.
- default locale, in this order: a repo decision (an ADR saying `en-IN`
  is `en-IN`, not `en`), the existing catalog's, then `en`.
- supported locales: the decision's list, else the existing catalog's
  plus the one requested. The check reads this list; it never infers
  the locales from whatever directories happen to exist.
- `make i18n-check` and `make check`: added to the Makefile when it
  exists; if absent, the check is still written and its command
  printed, and the gate is the stack's native test command.
- offline: never add, install or download a package (no package
  manager add or install, no Gradle dependency fetch), even with an
  offline flag set. A library the code needs is declared in
  the manifest, imported by the code, and named in the report as not
  installed; tests that `make check` runs must not import it.

## Steps

1. Resolve stack, source files and repo decisions as in Inputs. Read
   `references/i18n-checklist.md` once. Write down, before editing:
   default locale, supported locales, the saved-choice source (profile
   field, settings store, per-app language), the error contract
   (`code` or `messageKey`), and any existing suppression of
   translation checks (`disable += "MissingTranslation"`,
   `tools:ignore="MissingTranslation"`, an eslint i18n rule turned off,
   a skipped test). Each suppression is either removed in step 7 or
   named in the report with the reason it stays.
2. Audit the existing locales before adding one: for every locale
   already shipped, list keys missing against the default, keys whose
   placeholders differ in name, index or type, and plural sets missing
   a category the language needs. Type matters: `%1$d` where the
   default has `%1$s` throws `IllegalFormatConversionException` for
   every user of that language; `{nombre}` where the code passes `{name}`
   renders raw braces. Fix a placeholder that would crash or render
   raw, and name every key; a README saying a language is "complete"
   is a claim to check, not a fact.
3. Count the hard-coded strings. Grep, per stack, for text a user would
   read: JSX text nodes and `placeholder=`, `title=`, `aria-label=`
   literals, and strings built with `+` or template literals around a
   value (web, RN); `Text("`, `label = "`, `contentDescription = "`,
   `getString(...) +`, notification titles and `android:text="`
   literals in XML (Android); `Text("`, `Label("`, `Button("`,
   `.navigationTitle("` in SwiftUI (iOS). Also enum names or API
   `message` fields rendered as text. Exclude tests, storybook and
   fixtures. Print the count before any change.
4. Set up the catalog if missing: react-i18next with ICU
   (`i18next-icu`) or an existing in-repo lookup on web and RN;
   `res/values/strings.xml` plus `values-<lang>/` with `<plurals>` on
   Android; `Localizable.xcstrings` with `String(localized:)` on iOS.
   Keys dotted by feature and meaning (`invoice.list.empty`), never the
   English text. Keep every existing key: a key the code no longer
   references is reported as unused, never deleted in this task, since
   the server, a flavour or the next release may use it.
   Import existing translations by exact source match only. A vendor
   line whose English source differs from today's copy ("Save" against
   today's "Save changes") is stale: it goes on the worklist
   as needing re-translation, never into the catalog as current. A
   placeholder is code, not text: a translated or renamed placeholder
   is corrected to the code's name and flagged for the translator to
   confirm. Imported text keeps its provenance (vendor, human); only
   text you write yourself is a machine draft.
5. Move every string into the catalog and replace the literal with the
   lookup, keeping the copy word for word. An existing key whose text
   differs from the literal (key `Cancel` for a `Cancel order` literal) is
   not a match; add a new key, because reusing it changes the copy.
   Never drop a string instead of moving it: text shown before the
   locale is known (a loading state before the profile arrives)
   resolves from the browser or device, then the default, and keeps
   its accessible text. One message per sentence with
   placeholders, never fragments joined in code; a count is a plural
   message (ICU `plural`, `<plurals>` read with `pluralStringResource`
   or `getQuantityString`, iOS plural variation), including counts
   already in the catalog as plain strings ("Arriving in %1$d minutes"
   becomes a plural in every locale file). Do not swap a count for a
   different phrasing (`Due in 1 day` must not become `Due tomorrow`
   through `RelativeTimeFormat`) unless asked: that is a copy change.
   Dates, numbers and money through `Intl.DateTimeFormat`,
   `Intl.NumberFormat`, `NumberFormat.getCurrencyInstance` with
   `Currency.getInstance(code)`, `DateTimeFormatter.ofLocalizedDateTime`
   or `FormatStyle`, always passing the resolved locale. Minor units
   convert by the currency's own fraction digits
   (`Currency.defaultFractionDigits`, or the formatter's
   `resolvedOptions().maximumFractionDigits`), not a hard-coded 100:
   BHD, KWD and OMR have 3, JPY has 0. Keep the time zone
   the old code used (UTC stays UTC) unless a decision says otherwise;
   a visible change in date shape or zone is listed as a Proposed
   decision in the report. Update the tests that asserted the old
   output to the new output with an explicit locale; never delete a
   money or date test without its replacement.
6. Errors: the UI never shows a server `message` meant for logs. Map
   each documented `code` or `messageKey` to a catalog message, one
   key per code, with a generic catalog message for any unknown code
   and for network failures. Test the mapping including the unknown
   case.
7. Locale resolution, one function per stack, tested branch by branch:
   (a) the user's saved choice when it is set; if it is set but not
   supported, it goes through the fallback chain and then to the
   default, never to the device language, because the user chose;
   (b) the device or browser languages only when there is no saved
   choice, each through the fallback chain; (c) the default. The chain
   drops region before language (`hi-IN`, `hi`, then default); a
   supported `hi` region variant resolves to its sibling catalog. The
   catalog loader, the formatters and the document `lang` and `dir`
   (web) all read the result. Do not add `Accept-Language` headers or
   change API calls unless the API contract asks for it; say so as a
   follow-up instead.
8. RTL: `dir` on `html` from the resolved locale (web), `I18nManager`
   (RN), `android:supportsRtl="true"` with start and end everywhere
   including `absolutePadding`, `layout_marginLeft`, `gravity="left"`
   (Android), leading and trailing (iOS). Direction icons (back,
   forward, send) mirror: `Icons.AutoMirrored.*` on Compose. Values
   that stay left to right inside RTL text (tracking IDs, emails,
   amounts) are bidi-isolated (`BidiFormatter`, `<bdi>`, U+2068 and
   U+2069). List what was not rendered.
9. Untranslated text never reaches a user as a marker. A new locale
   file carries every key; a key not yet translated holds the default
   text, and its status lives outside the displayed value: a
   translator worklist file, XLIFF `state="needs-translation"`, or an
   xml comment. A `TODO(hi)` prefix in a value ships to users. Text
   you draft yourself (any language) is labelled machine draft in the
   worklist and in the report, and never called final or reviewed.
   Prove the fallback with the real catalog: one test renders a key
   awaiting translation in the new locale and gets the default text.
10. `i18n-check`, the gate. It reads the supported-locales list and
    fails when: a listed locale has no catalog, zero keys were
    compared, a key is missing from any listed locale's catalog (the
    worklist says what to translate; it never excuses an absent key,
    or deleting a key passes while every key awaits translation),
    placeholders differ between locales, a plural set lacks a category
    the language requires (CLDR: Arabic zero, one, two, few, many,
    other; Hindi one, other), or the code looks up a key the default
    catalog lacks (scan the `t('...')` calls: i18next renders a missing
    key's name to the user; Android's `R.string` already fails the
    compile). It prints
    `i18n-check: N keys, M locales, K missing, P placeholder
    mismatches, T awaiting translation, U unused`. Awaiting translation
    is counted, not fatal in `make check`: the release gate is a
    separate `i18n-check --release` that fails while T is above zero.
    Prove it in a scratch copy: delete one key from the new locale,
    delete the whole locale file, rename one placeholder, and add a
    lookup of an unknown key; show each fails. Web and RN: a small Node script with no
    dependencies; Android: lint with `MissingTranslation` as error, no
    extra script outside the app module; iOS: a script over the
    catalog JSON. If enabling the lint turns CI red (a shipped locale
    has gaps), say which keys and that CI fails until they are filled.
11. Run the gate and every test, then report as below. Nothing is
    committed; changes stay in the working tree. State what could not
    run here (no node_modules, no Android SDK, no device) and that the
    layouts were not rendered; never claim they passed.

## Output contract

```
## i18n: <stack> (<N> source files scanned)
Decisions followed: <file: line> (default <locale>, resolution order, error contract)
Catalog: <path> (<library>, not installed | in repo); locales: <list>
Hard-coded strings: before N, after M (<files still holding them, reason>)
Existing locale gaps: <locale: keys> | none
Imported translations: <N from file> | none; stale: <keys>; placeholder fixes: <keys>
Suppressions: <removed | kept, reason>
Awaiting translation: <locale: T keys, worklist path>; machine drafts: <count | none>
i18n-check: <its line> (make target | script only); release gate: <command>
gate: make check | <native command>: passed | failed (<target>) | not run (<why>)
Not run or not rendered: <list>
Proposed decisions: <visible changes the user should confirm>
```

## Gotchas

- Never concatenate translated fragments; word order differs by
  language. One message with placeholders.
- A key named after its English text breaks the moment the English
  changes. Keys name the place and the meaning.
- `toLocaleString()` without a locale argument uses the runtime's
  locale, not the user's. Always pass the resolved locale.
- Indian numbering (`12,34,567`) comes from `en-IN`, not from a custom
  formatter; `en` or `en-US` gives `1,234,567`. Currency is the ISO code
  through the formatter, never a `Rs` or `SAR ` prefix in a string.
- `ar` and `ar-SA` format digits as Arabic-Indic by default in ICU and
  in `String.format` with an Arabic locale. Whether the app shows them
  is a product decision; name it rather than force `-u-nu-latn`.
- Arabic `one` and `two` are separate categories from `other`; a plural
  set with only `one` and `other` renders wrong for 2 and 3 to 10.
- An untranslated value copied with a `TODO(<locale>)` prefix is shown
  to users verbatim; an empty string may render blank. Keep status
  outside the value.
- A check that discovers locales from directories passes when a whole
  locale is deleted. It must read the declared list.
- Android `values-b+sr+Latn` style qualifiers for script variants;
  `values-hi` alone is fine for Hindi. `translatable="false"` strings
  are not copied into locale files.
- iOS String Catalog entries with no translation fall back to the
  development language silently; `i18n-check` is the only thing that
  notices.
- A translation vendor keys its file by the English it was sent. Copy
  edited since then makes that line stale; importing it ships the old
  meaning. Match on the exact source, then check the placeholders.
- `minor / 100.0` with `%.2f` shows 1.250 KWD as `12.50`; the currency's
  fraction digits come from `Currency` or `Intl.NumberFormat`.
- Pseudo-locales (`en-XA` long text, `ar-XB` RTL, `pseudoLocalesEnabled`
  on Android debug) find truncation before a translator does.
