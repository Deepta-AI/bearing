# design-directions: the react-shadcn build

Read when the target is React with shadcn/ui and Tailwind (step 6).

6. react-shadcn build (instead of step 7):
   - One file per direction, `src/design/variants/<n>-<name>.css`,
     overriding `--font-sans`, `--font-mono`, the type scale, the colour
     roles shadcn reads (`--background`, `--foreground`, `--card`,
     `--primary`, `--primary-foreground`, `--muted`, `--muted-foreground`,
     `--accent`, `--border`, `--input`, `--ring`, `--destructive`, and
     `--sidebar-*`, `--chart-*` where used), `--radius`, spacing, shadows
     and motion easing.
   - Selectors match where the app sets things. Read the theme code for
     the element that gets the dark class or attribute, put the direction
     attribute on the same element, and write light as
     `:root[data-variant="<n>-<name>"]` and dark as
     `:root[data-variant="<n>-<name>"].dark` (or `[data-theme="dark"]`,
     whichever the app sets). A bare `[data-variant]` ties `:root` on
     specificity and wins only by import order, which a refactor breaks.
     Dark under `@media (prefers-color-scheme)` alone is wrong when the
     app stores the user's choice.
   - The default look is untouched: `:root` and `.dark` keep their
     values, and nothing applies without the switch.
   - The switch: the project's design gallery when one exists. Without
     one, add a dev-only switch (read `?variant=` in the entry file behind
     `import.meta.env.DEV`, set the attribute on the root element, import
     the direction's CSS) so the real routes render each direction. Print
     how to view each one.
   - Colours found in step 2 move onto variables whose defaults equal the
     old values (the default look stays the same) so each direction can
     set them, or they are listed as not following the directions.
   - Density and shape go through variables, or through neutral hook
     attributes (`data-slot`, `data-part`) styled under the direction's
     selector; never per-direction class names or conditionals in
     components. A direction restyles: it adds no content, fields,
     computed values or controls.
   - Targets: when phones are among the users, every direction reaches
     44 px (or the project's floor) at phone width.
   - Fonts: the faces already bundled, or new ones as Fontsource packages
     or self-hosted files, never a third-party host when the CSP or an ADR
     forbids it; the CSP is never loosened. Packages added but not
     installed are said to be not installed; a face with no self-hostable
     source is dropped with the reason.
   Then step 8, and continue at step 9.
