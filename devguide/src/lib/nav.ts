import type { NavGroup, NavItem } from "@ui";

export type { NavGroup, NavItem };

/** The chapters are a reading order, so they carry numbers; the reference does not. */
export const NAV: NavGroup[] = [
  {
    title: "Read in order",
    items: [
      { to: "/", label: "Overview", n: "0" },
      { to: "/start", label: "Where to start", n: "1" },
      { to: "/architecture", label: "The five layers", n: "2" },
      { to: "/session", label: "A session, event by event", n: "3" },
      { to: "/guard", label: "The guard", n: "4" },
      { to: "/skills-work", label: "How skills work", n: "5" },
      { to: "/agents", label: "The seven agents", n: "6" },
      { to: "/scaffold", label: "Scaffolding a repository", n: "7" },
      { to: "/adopt", label: "Adopting a repository", n: "8" },
      { to: "/autopilot", label: "Autopilot and the task loop", n: "9" },
      { to: "/trackers", label: "Trackers", n: "10" },
      { to: "/harnesses", label: "Other harnesses", n: "11" },
      { to: "/install", label: "Install, doctor, packs", n: "12" },
      { to: "/gates", label: "Gates, tests and CI", n: "13" },
      { to: "/change", label: "Changing Bearing", n: "14" },
      { to: "/release", label: "Releasing", n: "15" },
    ],
  },
  {
    title: "Reference",
    items: [
      { to: "/scripts", label: "Every script", prefix: true },
      { to: "/skills", label: "Every skill", prefix: true },
      { to: "/replays", label: "Terminal replays" },
      { to: "/glossary", label: "Glossary" },
    ],
  },
];

export const ORDER: NavItem[] = NAV[0].items;
