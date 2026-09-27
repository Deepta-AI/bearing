# React guidelines

## Project shape

- `src/features/<feature>/` owns one domain: `api.ts` (fetch functions),
  `schemas.ts` (Zod), `hooks.ts` (keys and query hooks), `components/`.
  Other code imports the file that defines the symbol. No barrel
  `index.ts` that re-exports a feature or a folder: it pulls every module
  it lists into the importer's graph, slows the dev server and defeats
  route splitting.
- `src/app/` is wiring: providers, router, layout, global client stores.
- `src/components/ui/` is shadcn output. Add with `pnpm dlx shadcn@4.21.0
  add <name>`, never hand-edit, never review. `src/components/` holds shared
  components built on top of them.
- `src/lib/` holds the api client, the query client, env parsing and `cn`.
  No `utils.ts` dumping ground beyond `cn`.
- A component file under 200 lines with one component exported. Helpers that
  grow move to a sibling file, not to the bottom of the component.

## State

- Server state lives in the TanStack Query cache and nowhere else. Read it
  with `useQuery`, shape it with `select`, change it with a mutation that
  invalidates or `setQueryData`. Copying a query result into `useState` or a
  store creates a second source of truth that goes stale.
- Client state that more than one component needs goes in a Zustand store
  under `src/app/stores/` or the feature. Select narrowly:
  `useUiStore((s) => s.sidebarOpen)`, never the whole store.
- Local state (`useState`) for things one component owns: open, hovered,
  draft text. Lift it only when a second component needs it.
- Derived state is computed during render. `const total = items.reduce(...)`
  in the body, not in an effect that sets state.
- URL state (filters, page, selected id) lives in typed search params
  validated with Zod on the route, so it survives reload and is shareable.
  Param names are a contract with every link already built to the route;
  keep them. A filter change resets the page; typing uses `replace`.
- Local state that belongs to one entity (a draft for this customer) is
  reset when the entity changes: `key={id}` on the owning component.

## Data fetching

- One fetch function per endpoint in `api.ts`, built on `apiFetch(path,
  schema, init)` from `src/lib/api.ts`. It validates the body with Zod and
  throws `ApiError` with status and code; components never see raw
  `Response`.
- Query keys from a factory per feature:
  `const invoiceKeys = { all: ['invoices'] as const, list: (f: Filters) =>
  [...invoiceKeys.all, 'list', f] as const, detail: (id: string) =>
  [...invoiceKeys.all, 'detail', id] as const }`. Every argument the fetch
  uses is in the key.
- Define `queryOptions` once per query in `hooks.ts` and reuse them in
  `useQuery`, `useSuspenseQuery`, route loaders and prefetches.
- Pass the `signal` from the query function to `fetch` so a navigation
  cancels the request.
- Every request goes through `apiFetch`, which throws on a non-2xx status;
  a 204 endpoint passes `z.undefined()` as the schema, never a bare `fetch`
  whose status nobody reads.
- Mutations: `onSuccess` invalidates the affected keys (the same key the
  list query uses, from the factory); `onError` shows the failure; optimistic updates
  only with a rollback in `onError` and a measured need.
- No request waterfalls. A route's data is started in its loader, all at
  once: `await Promise.all([qc.ensureQueryData(a), qc.ensureQueryData(b)])`,
  not one after another and not in the components that render it. A
  child component that starts its own query only after the parent's
  query resolves (a chain of `useSuspenseQuery` down the tree) is a
  waterfall; hoist the independent reads to the loader or use
  `useSuspenseQueries`. A dependent query (`enabled: !!user`) is fine
  when it truly needs the first result.
- Every query consumer renders four states: pending, error (with retry),
  empty, data. A component that only renders the data branch is a finding.

## Routing

- Code-based TanStack Router in `src/app/routes.tsx`: `createRootRoute`,
  `createRoute`, `addChildren`, one `createRouter` with `queryClient` in the
  context. Register the router type once so `Link` and `useParams` are typed.
- `validateSearch` with a Zod schema on every route that reads the URL.
- Loaders call `context.queryClient.ensureQueryData(options)`; the component
  then uses `useSuspenseQuery` with the same options.
- Lazy-load route components with `lazyRouteComponent` once a route pulls in
  a heavy dependency (charts, editors). The main bundle stays under the
  budget in `vite.config.ts`.

## Forms and validation

- One Zod schema per form; `z.infer` gives the values type. Parse on submit,
  show field errors from the parsed issues.
- Inputs are controlled or uncontrolled for their whole life. `value={x ??
  ''}` when the value can be undefined, so React never switches modes.
- Server-side validation errors map onto fields once, in the submit handler.

## Components

- Function components, props typed inline or with a `Props` type next to the
  component, no `React.FC`.
- `key` is a stable id from the data, never the array index, on any list
  that reorders, filters or edits.
- `useEffect` synchronises with the outside world and returns a cleanup.
  Every dependency it reads is in the array; if the array is wrong, the
  effect is wrong, not the lint rule.
- Callbacks passed to memoised children or used in effect dependencies are
  the only candidates for `useCallback`. Otherwise plain functions.
- Lists over roughly 200 rows are virtualised (`@tanstack/react-virtual`);
  render a page, not the dataset.
- Errors are caught by an error boundary per route and a top-level one that
  reports to the error tracker.

## Styling

- Tailwind utilities with the tokens from `src/index.css`. Spacing on the
  scale, colours by role (`bg-primary`, `text-destructive`), radii by
  `rounded-md` and friends. An arbitrary value needs a comment saying why.
- Variants with `cva`; class merging with `cn` from `src/lib/utils.ts`.
- Dark mode via the `.dark` class and the token set, never per-component
  colour branches.
- No CSS modules, no styled-components, no inline `style` except for values
  computed at runtime (a progress width).

## Accessibility

- Interactive elements are native (`button`, `a`, `input`, `select`); a
  `div` with `onClick` is a finding.
- Every form control has a `label` (visible or `sr-only`) and an error
  message linked with `aria-describedby`.
- Icon-only buttons carry `aria-label`; decorative icons carry
  `aria-hidden`.
- Focus is visible (`focus-visible:ring`), trapped in dialogs (shadcn does
  this), and returned on close.
- Loading and result regions use `role="status"` or `aria-live="polite"`.
- `eslint-plugin-jsx-a11y` is on in `make check`; Playwright specs include a
  keyboard path for every flow they cover.

## Untrusted content

- Text from the API or the user (notes, comments, names, pasted email) is
  rendered as a React text child. Line breaks come from
  `whitespace-pre-line`, not from building HTML.
- `dangerouslySetInnerHTML` only for HTML that must stay HTML, sanitised
  with DOMPurify at the point of render; say where it came from.
- Links built from data allow `http:` and `https:` only; `target="_blank"`
  carries `rel="noopener noreferrer"`.

## Configuration

- `src/lib/env.ts` parses `import.meta.env` with Zod at startup and exports
  the typed result. Nothing else reads `import.meta.env`.
- Only `VITE_`-prefixed variables reach the bundle, and they are public. No
  secret, token or private URL ever goes in one.
- `.env.example` lists every variable with a placeholder.

## Testing

- vitest with jsdom and Testing Library. Query by role and accessible name
  (`getByRole('button', { name: /retry/i })`), never by class or test id
  unless there is no accessible handle.
- A fresh `QueryClient` with `retry: false` per test, rendered through a
  `renderWithProviders` helper.
- The API is mocked at the network with MSW: `src/test/msw.ts` holds one
  default handler per route the app calls, `setup.ts` starts it with
  `onUnhandledRequest: "error"`, and a test that needs another answer calls
  `server.use(...)`. The request goes through the real `apiFetch`, URL and
  Zod parse, so a wrong path or a schema drift fails the test. Assertions
  cover pending, error and data.
- `vi.stubGlobal("fetch")` is for `src/lib/api.test.ts` alone, where the
  assertion is on the request the client builds (headers, body, method).
- Playwright: one spec per user-facing flow, API mocked with `page.route`,
  assertions on visible text and roles, a keyboard path where the flow has
  one. Never a `waitForTimeout`.
- Coverage thresholds are 80 percent on lines, branches, functions and
  statements. The threshold is a floor; a bug fix ships with its test.

## Performance

- Measure with the React profiler and the Vite bundle report before adding
  memoisation or splitting.
- Heavy dependencies are imported in the route that needs them, not in
  `App.tsx`. A dependency over 50 KB gzipped is a review question.
- A library whose entry point re-exports thousands of modules (icon sets,
  `lodash`, `date-fns`) is imported by subpath where it ships typed
  subpaths (`lodash-es/debounce`, `date-fns/format`); otherwise by named
  import from an ESM build, and the bundle report is checked once.
- Images have width and height set; below-the-fold images are `loading="lazy"`.

## Style

- Prettier and ESLint decide style. Nothing is discussed in review that a
  tool decides.
- Imports ordered by the lint rule: builtin, external, internal (`@/`),
  parent, sibling. Absolute `@/` imports across features; relative within a
  feature.
- No default exports except the route component that `lazyRouteComponent`
  requires and the config files.
- No `any`, no non-null assertion, no `as` cast to silence the compiler. A
  type guard or a schema parse instead.
