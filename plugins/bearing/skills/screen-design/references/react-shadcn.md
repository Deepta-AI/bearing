# screen-design: react-shadcn, screens as code

Read when the target is react-shadcn and the gallery can run for the reviewer.

### react-shadcn (screens as code)

1. Per screen a presentational view in
`src/features/<feature>/components/<Name>View.tsx`: props in, markup
out, no fetching, built only from `src/components/ui` and layout
utilities on the spacing scale; colours by role (`bg-card`,
`text-muted-foreground`), never a literal; the type scale the tokens
set; a `Skeleton` loading layout that holds the success layout's
shape.
2. The shell once for every screen, following the flows' navigation map,
with the feature's entry marked current. Change only the entry list
of an existing shell.
3. Per screen `src/features/<feature>/screens/<id>-<name>.screen.tsx`
exporting `screen: ScreenSpec` (`id`, `name`, `feature`, `job`,
`states`), one entry per state from the reconciliation, rendering the
view with fixtures in the flows' copy. Fixtures use invented companies
and people on reserved domains (`example.com`, `example.in`).
4. Responsive by design: at 375 the table becomes a card list or scrolls
inside its own container with the key columns readable, two columns
stack, the primary action stays reachable without horizontal scroll;
at 1440 no half-width column beside dead space.
5. Gates: `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/gallery_check.py" --src <src> --flows <flows file>`
until it exits 0; then the repository's own checks that exist (`make
check`, `make design-lint`). A target that does not exist, or a build
that needs `node_modules` that are absent, is reported as not run.
6. Screenshots from the running gallery when it runs
(`<id>?state=<name>&chrome=0`):
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py" shoot --base http://localhost:<port>/__design/ --out docs/design/screens/shots <id>?state=<state>&chrome=0...`
then `check`. `docs/design/screens/README.md` lists the screens,
states and the gallery URL.
