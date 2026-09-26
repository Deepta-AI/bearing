import { data } from "./data";

export type NavItem = { to: string; label: string; swatch?: string };
export type NavGroup = { title: string; items: NavItem[] };

const flowSwatch: Record<string, string> = { greenfield: "var(--jade)", bugfix: "var(--warn)", feature: "var(--gsd)", inherited: "var(--sp)" };

export const NAV: NavGroup[] = [
  {
    title: "Start",
    items: [
      { to: "/", label: "Overview" },
      { to: "/start", label: "Get started" },
      { to: "/files", label: "Default files" },
      { to: "/concepts", label: "How skills work" },
    ],
  },
  {
    title: "Flows",
    items: data.flows.map((f) => ({ to: `/flows/${f.id}`, label: f.title, swatch: flowSwatch[f.id] })),
  },
  {
    title: "Workflow",
    items: [
      { to: "/workflow", label: "Every stage" },
      { to: "/skills", label: "Skill catalogue" },
      { to: "/example", label: "A recorded task" },
    ],
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
export const ORDER: NavItem[] = NAV.flatMap((g) => g.items);
