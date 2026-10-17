# design-system: what to settle from the files before choosing a value

Read when: before step 1, and again at the lint when the scale source line looks wrong.

A generalist writes correct tokens in the wrong form. Settle these from
the files, and name each answer in the report:

1. **What consumes the variables.** Tailwind 3 with colours written
`hsl(var(--x))` needs HSL channels (`152 64% 30%`); hex, oklch or a
full `hsl()` there makes every colour silently vanish. Tailwind 4 with
`@theme inline` takes full colours. Plain CSS takes full colours.
Native stacks per `references/stack-bindings.md`. The config is not
the only reader: grep `var(--` across `src` and `index.html` for
inline styles, chart or canvas code that builds `hsl(${...})` from
`getComputedStyle`, and a `<meta name="theme-color">` literal; each
keeps working in the form chosen, or changes with it.
2. **The browser floor.** `browserslist`, `.browserslistrc`, an ADR, the
README, Vite `build.target`. Safari before 15.4 has no `oklch()` or
`color-mix()`. A custom property holding hex then oklch does not fall
back: the oklch value wins and old browsers get no colour. With no
known floor, or a floor below the feature, ship sRGB; oklch lives in
`tokens.json` and, at most, in an `@supports (color: oklch(0 0 0))`
block.
3. **The dark switch.** Three things must name the same selector: what
the code toggles (`data-theme` attribute, `.dark` class, or only
`prefers-color-scheme`), the CSS block carrying the dark values, and
the framework's dark variant (Tailwind 3 `darkMode`, Tailwind 4
`@custom-variant dark`). A shadcn repo whose toggle sets `data-theme`
while the CSS says `.dark` has never had a dark mode; fix the mismatch
and say it was broken. Then first paint: a theme read from storage or
`matchMedia` and applied in a React effect paints light first for
every dark user on every load. Set the attribute from an inline script
in `index.html` before the bundle, or have the CSS apply dark under
`@media (prefers-color-scheme: dark)` when no choice is stored (the
`:root:not([data-theme="light"])` form), and say which.
4. **Which document wins.** When a token file, a contributing guide and a
direction disagree (a spacing scale against "any multiple of 4"),
follow the one that states its own precedence, else the token file,
and raise the conflict with both texts quoted.
5. **Where the checks run.** The CI job's image, what it installs and
what `make check` calls. A check needing bash or python3 does not run
on `node:*-alpine`; a check's own tests must run there too.
