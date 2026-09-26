import type { NavGroup, NavItem } from "@ui";
import { readingOrder } from "@ui";
import { data } from "./data";

export type { NavItem };

const flowSwatch: Record<string, string> = { greenfield: "var(--ok)", bugfix: "var(--gate)", feature: "var(--gsd)", inherited: "var(--sp)" };

export const catSlug = (c: string) => c.toLowerCase().replace(/[^a-z0-9]+/g, "-");
export const catLabel = (c: string) => (c === "genai" ? "GenAI" : c.charAt(0).toUpperCase() + c.slice(1));

/** Grouped the way a reader looks for things: set up, the stages, the skills, the flows, then reference. */
export const NAV: NavGroup[] = [
  {
    title: "Get started",
    items: [
      { to: "/", label: "Overview" },
      { to: "/start", label: "Install and set up" },
      { to: "/concepts", label: "How skills work" },
      { to: "/files", label: "Default files" },
      { to: "/example", label: "A recorded task" },
    ],
  },
  {
    title: "Workflow stages",
    items: data.stages.map((s, i) => ({ to: `/workflow/${i + 1}`, label: s.title, n: String(i + 1), also: i === 0 ? ["/workflow"] : undefined })),
  },
  {
    title: "Skills",
    items: [
      { to: "/skills", label: "All skills", prefix: true },
      ...data.categories.map((c) => ({ to: `/skills#${catSlug(c)}`, label: catLabel(c) })),
    ],
  },
  {
    title: "Flows",
    items: data.flows.map((f) => ({ to: `/flows/${f.id}`, label: f.title, swatch: flowSwatch[f.id] })),
  },
  {
    title: "Reference",
    items: [
      { to: "/reference/config", label: "Configuration" },
      { to: "/reference/security", label: "Security model" },
      { to: "/reference/packs", label: "Packs and cost" },
      { to: "/reference/harnesses", label: "Other harnesses" },
      { to: "/reference/versioning", label: "Versioning" },
      { to: "/faq", label: "Troubleshooting" },
      { to: "/rules", label: "Rules" },
    ],
  },
];

/** Reading order for the previous and next links at the foot of each page. */
export const ORDER: NavItem[] = readingOrder(NAV);
