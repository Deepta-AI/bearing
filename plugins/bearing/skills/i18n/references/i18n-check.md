# i18n: the i18n-check gate

Read when you write or extend the check (step 10): what it fails on, how to prove it, and the per-stack form.

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
