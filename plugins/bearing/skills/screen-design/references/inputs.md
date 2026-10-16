# screen-design: inputs and their fallbacks

Read when a source is missing or unclear (Inputs): flows, requirements, tokens, existing mockups, manifest, component contract, event sheet.

- Inventory, states, copy and navigation: the newest
  `docs/design/flows/<feature>/flows*.md` (sections 1, 2, 4 and 7); if
  absent, the stories in `docs/product/backlog.md` or
  `docs/product/PRD.md` (navigation proposed and raised as `ambiguity`);
  if absent, the routes and screens in the code; if absent, one question
  for a one-paragraph brief. `--screens` limits the set.
- Requirements: `docs/product/PRD.md` with its version and changelog;
  Accepted ADRs in `docs/adr/`; the API client and its types (statuses,
  error codes, fields) for every call a screen makes.
- Tokens: the file an ADR or README names as the source of colour (on
  react-shadcn usually `src/index.css`); else `docs/design/tokens.css`;
  else generated from `docs/design/tokens.json` with `system_page.py
  tokens-css`; else written by hand from the approved variant, else
  `DESIGN.md`, else the brief, headed `proposed`.
- Existing mockups: pages already under `docs/design/screens/<feature>/`
  and how they are made (a build script, a JSON source, a template, a
  README note). A repository's own mockup system is used as it is.
- Manifest: `docs/design/design.json` (`templates/design.schema.json`),
  for a new HTML bundle or one already using it.
- Component contract: `docs/design/components.md`; if absent,
  `data-component` names come from the region's role and the index says
  `no contract`.
- Event sheet: `docs/analytics/EVENT_SHEET.md`; if absent, no
  `data-event` attributes and the index says `no sheet`.
