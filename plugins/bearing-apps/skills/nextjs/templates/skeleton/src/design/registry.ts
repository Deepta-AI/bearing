import type { ScreenModule, ScreenSpec } from "./screen";
import { screenModules, variantNames as generatedVariants } from "./screens.generated";

// Every *.screen.tsx under src/features, listed by scripts/design-registry.mjs
// (Next.js has no import.meta.glob). A new screen file appears in the gallery
// after `make design-registry`, which make dev runs first.
export function allScreens(found: ScreenModule[] = screenModules): ScreenSpec[] {
  return found
    .map((m) => m.screen)
    .sort((a, b) => a.id.localeCompare(b.id, undefined, { numeric: true }));
}

// Design directions from design-directions: src/design/variants/<n>-<name>.css,
// each overriding the tokens under [data-variant="<n>-<name>"], so three
// directions render the same screens with the same components and differ
// only where a direction may: type, colour, density, radius, motion.
export const variantNames: string[] = [...generatedVariants].sort();

export interface GallerySearch {
  state?: string | undefined;
  theme?: "light" | "dark" | undefined;
  chrome?: "0" | "1" | undefined;
  variant?: string | undefined;
}

export function parseGallerySearch(search: Record<string, unknown>): GallerySearch {
  const theme = search.theme === "dark" || search.theme === "light" ? search.theme : undefined;
  const chrome = search.chrome === "0" || search.chrome === 0 ? "0" : undefined;
  const state = typeof search.state === "string" ? search.state : undefined;
  const variant =
    typeof search.variant === "string" && /^[0-9]+-[a-z0-9-]+$/.test(search.variant)
      ? search.variant
      : undefined;
  return { state, theme, chrome, variant };
}

/** galleryEnabled: on in `next dev`, and in a build only with DESIGN_GALLERY=1. */
export function galleryEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return env.NODE_ENV !== "production" || env.DESIGN_GALLERY === "1";
}

/** searchToQuery writes a gallery search back into a query string. */
export function searchToQuery(search: GallerySearch): string {
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(search)) {
    if (typeof v === "string") q.set(k, v);
  }
  const s = q.toString();
  return s ? `?${s}` : "";
}
