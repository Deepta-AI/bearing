# i18n: counting strings, the catalog, moving strings and formatting

Read when you run steps 3 to 5: the per-stack grep patterns, catalog setup, importing translations, plurals, dates, numbers and money.

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
