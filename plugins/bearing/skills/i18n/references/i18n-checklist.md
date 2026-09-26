# i18n checklist

Walk this per stack before calling a screen or feature localised. Each
line is pass, fail or n/a with a file and line as evidence.

## Strings

- [ ] No user-facing literal in source. Grep patterns per stack in the
      skill's step 2; the count after the run is zero or every remaining
      hit has a reason next to it.
- [ ] Keys are dotted by feature and meaning (`invoice.list.empty`), not
      the English text, not a number.
- [ ] One default locale file is complete; every other locale is checked
      against it by `make i18n-check`.
- [ ] Error messages come from the API as `messageKey` and are looked up
      in the catalog; the raw server message never reaches the UI.
- [ ] Accessibility strings (`aria-label`, `contentDescription`,
      `accessibilityLabel`) are in the catalog too.
- [ ] Logs and analytics event names stay in English and outside the
      catalog; they are not user-facing.

## Plurals and gender

- [ ] Every count message is a plural rule (ICU `plural`, Android
      `<plurals>`, iOS plural variation), never `count > 1 ? "s" : ""`.
- [ ] `zero`, `one`, `two`, `few`, `many`, `other` are all present where
      the target language needs them (Arabic and Russian need all six;
      Hindi needs `one` and `other`).
- [ ] Gendered messages use ICU `select` with an `other` branch.

## Formatting

- [ ] Dates through `Intl.DateTimeFormat`, `DateUtils` or `FormatStyle`
      with the resolved locale and the user's time zone; no `dd/MM/yyyy`
      literal anywhere.
- [ ] Numbers through `Intl.NumberFormat` or the platform equivalent;
      Indian grouping comes from `en-IN`.
- [ ] Currency through the formatter with the ISO code; the symbol is
      never in the string. Amounts are minor units (paise) in the API and
      formatted at the edge.
- [ ] Relative times ("3 minutes ago") through `Intl.RelativeTimeFormat`
      or the platform's, not a hand-written table.
- [ ] Lists ("a, b and c") through `Intl.ListFormat` or
      `ListFormatter`.
- [ ] Sorting through `Intl.Collator` or `localeCompare` with the
      locale; never a plain `<` on strings shown to users.

## Locale resolution

- [ ] One function returns the effective locale: saved choice, then
      device, then the fallback chain, then `en`.
- [ ] The fallback chain drops the region before the language (`hi-IN`
      to `hi` to `en`).
- [ ] Changing the language in-app re-renders without a restart (web,
      RN) or recreates the activity (Android) or updates the environment
      (iOS); the saved choice survives a relaunch.
- [ ] `Accept-Language` is sent on every API call so server-generated
      content (emails, PDFs) uses the same locale.

## Layout and RTL

- [ ] Start and end, leading and trailing; no left or right in layout
      code that carries meaning.
- [ ] Icons that imply direction (back, forward, send) mirror in RTL;
      icons that do not (play, clock) do not.
- [ ] No fixed-width text containers; labels wrap or ellipsise with a
      tooltip or accessibility label for the full text.
- [ ] German-length pseudo-locale (text 30 percent longer) rendered on
      the main screens without clipping.
- [ ] Input fields accept non-Latin scripts and the locale's decimal
      separator; numeric keyboards on mobile still allow the comma
      where the locale uses it.

## Fonts and assets

- [ ] The font covers the script (Devanagari, Arabic, CJK) or falls back
      to a system font that does; a missing glyph renders as a box and
      is a finding.
- [ ] Images with text are localised or replaced with text over an
      image.

## Tooling

- [ ] `make i18n-check` runs in `make check`, fails on missing keys, and
      prints the count it compared.
- [ ] Unused keys are reported and removed within the same task.
- [ ] Translation files are sorted by key so diffs are readable.
- [ ] A new locale starts as a full copy of the default marked
      `TODO(<locale>)`, so the check fails until it is translated.
