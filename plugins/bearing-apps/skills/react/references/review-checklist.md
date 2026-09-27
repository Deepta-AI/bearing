# React review checklist

For each item, either find the concrete failure or write "none found".

## State
- A query result copied into `useState`, a `useRef` or a Zustand store; a
  store field that the server owns.
- A `useEffect` that calls a setter to derive state from props or other
  state; a `useEffect` with a missing dependency or a disabled lint rule.
- Derived data recomputed in an effect instead of during render.
- Client state in the URL that is not validated, or URL state duplicated in
  a store; a param renamed or invented where links to the route already
  exist (docs, helpdesk, emails); a page number that can outlive its filter.
- Per-entity `useState` (draft, open form, summary) in a component that is
  not keyed by the entity id, so it carries over when the route param
  changes.
- A leak fixed without cleanup: `persist` removed but the written key never
  cleared; a shipped secret removed but not rotated.

## Data fetching
- A query key missing an input the query function uses (filters, page, id,
  locale); a key built by hand instead of from the feature's factory.
- A fetch that bypasses `apiFetch`, skips the Zod parse, ignores the
  `signal`, or never checks `res.ok` (a DELETE whose 403 reads as success).
- A mutation that does not invalidate or update the keys it changed; an
  optimistic update without a rollback.
- A consumer that renders only the data branch: missing pending, error
  (with retry) or empty state.
- A request waterfall: a loader that awaits independent queries in
  sequence; a component whose query starts only after its parent's
  resolves when the two do not depend on each other.

## Types and validation
- An interface or type that duplicates a Zod schema instead of `z.infer`.
- Data crossing a boundary (API response, form, search params, env) without
  a schema parse.
- `any`, a non-null assertion, or an `as` cast that hides a real gap.

## Components
- `key` from the array index on a list that reorders, filters or edits;
  a missing key.
- A stale closure: a callback or effect reading a value from a previous
  render (setInterval, event listener, debounced handler).
- An input switching between controlled and uncontrolled (`value` that is
  sometimes undefined).
- `useMemo`, `useCallback` or `React.memo` added without a measurement.
- A list over roughly 200 rows rendered without virtualisation.
- A shadcn component edited in `src/components/ui`, or wrapped in a
  same-named component that only forwards props.

## Accessibility
- A `div` or `span` with `onClick`; an interactive element not reachable by
  keyboard; a click handler without a keyboard equivalent.
- A form control without a label; an icon-only button without `aria-label`;
  an error message not linked to its field.
- A loading or result region without `role="status"` or `aria-live`.
- Focus lost after a dialog closes or a list item is removed.
- A jsx-a11y rule disabled.

## Styling
- An arbitrary Tailwind value (`w-[137px]`, `text-[#333]`) without a comment
  saying why the scale does not fit.
- A colour or spacing literal outside the tokens; a per-component dark mode
  branch; an inline `style` for a static value.

## Security and configuration
- A secret, token or private URL in a `VITE_` variable, in `.env.example`
  or in the bundle.
- `import.meta.env` read outside `src/lib/env.ts`.
- `dangerouslySetInnerHTML` with API or user text (notes, comments,
  pasted email), including a `replace(/\n/g, "<br>")` that turns text into
  HTML; a `href` built from user input without a scheme check.

## Bundle
- A heavy dependency imported at the top level instead of in the route that
  uses it; a whole icon or utility library imported for one symbol.
- A barrel `index.ts` that re-exports a feature or folder, or an import
  through one.
- A route without `lazyRouteComponent` that pulls in charts, editors or
  maps.

## Tests
- A bug fix without a reproducing test.
- A test querying by class or test id where a role exists; a test that
  reaches the network, a real timer or `waitForTimeout`.
- A feature or component test that stubs `fetch` instead of adding an MSW
  handler; a new API route with no default handler in `src/test/msw.ts`.
- A test QueryClient without `retry: false`; a test that cannot fail.
- A new flow without a Playwright spec, or a spec that reaches a real API.

## Hygiene
- `eslint-disable` added; a lint rule loosened; a dependency added unasked.
- Em dash in a comment or doc.
