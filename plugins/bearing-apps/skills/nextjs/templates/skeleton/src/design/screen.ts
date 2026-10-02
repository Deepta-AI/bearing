import type { ReactNode } from "react";

/**
 * A screen design as code. screen-design writes one
 * `src/features/<feature>/screens/<id>-<name>.screen.tsx` per screen in the
 * flows inventory, exporting `screen`. Each state renders the real page
 * components with fixture props, so the design is the implementation: the
 * route wires the same components to live data.
 *
 * The gallery is a client component, so a screen file and everything it
 * imports reach the browser: import the presentational view (props in,
 * markup out), never the module that fetches, reads the environment or
 * imports "server-only". Keep the view in a file of its own.
 */
export interface ScreenSpec {
  /** The inventory id from docs/design/flows, e.g. "S-12". */
  id: string;
  /** The screen's name from the inventory. */
  name: string;
  /** The feature folder it belongs to. */
  feature: string;
  /** The screen's single job, in one sentence. */
  job: string;
  /** One entry per inventory state: loading, empty, error, success, partial and the screen's own. */
  states: Record<string, () => ReactNode>;
}

export interface ScreenModule {
  screen: ScreenSpec;
}
