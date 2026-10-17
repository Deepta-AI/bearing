# i18n: locale resolution and RTL

Read when you run step 7 or 8: the resolution function and right to left layout.

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
