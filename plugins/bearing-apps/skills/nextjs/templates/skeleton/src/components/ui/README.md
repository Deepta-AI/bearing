# src/components/ui

shadcn/ui (new-york style, Tailwind v4), as `pnpm dlx shadcn@latest add`
writes it, so every screen is assembled from one component set and one
set of tokens. Screens import from here; a raw `<table>`, `<button>`,
`<input>`, `<select>` or `<dialog>` in feature code is a design-lint
finding.

The inventory: alert, avatar, badge, breadcrumb, button, card, checkbox,
command, dialog, dropdown-menu, hover-card, input, label, pagination,
popover, progress, radio-group, scroll-area, select, separator, sheet,
sidebar, skeleton, slider, sonner (toasts), switch, table, tabs,
textarea, toggle, toggle-group, tooltip; `src/hooks/use-mobile.ts` backs
the sidebar.

Four edits to the generated files, kept when regenerating:

- `cn` comes from `@/lib/utils` (clsx and tailwind-merge), not the `cn`
  package the generator now adds: one tested helper, one fewer
  dependency.
- `sonner.tsx` takes `theme` as a prop (default `system`) instead of
  reading `next-themes`; the app sets the `.dark` class itself.
- `dropdown-menu.tsx` (`checked`) and `slider.tsx` (`value`,
  `defaultValue`) pass optional props only when set, because the
  template compiles with `exactOptionalPropertyTypes`.
- `use-mobile.ts` subscribes with `useSyncExternalStore` instead of
  setting state in an effect (react-hooks/set-state-in-effect).

Add a component with `pnpm dlx shadcn@latest add <name>` through the
repository's make targets, then apply the same edits. Colours, radius,
type and motion come from the tokens in `src/styles/tokens.css`
(design-system); never edit a colour here.
