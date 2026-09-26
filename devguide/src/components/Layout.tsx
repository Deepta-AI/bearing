import { Shell, type SearchItem } from "@ui";
import sections from "virtual:sections";
import { data } from "../lib/data";
import { NAV } from "../lib/nav";

export { Mark } from "@ui";

/** Everything search can find: chapters and their sections, scripts, skills, agents, make targets and tests. */
function buildIndex(): SearchItem[] {
  const out: SearchItem[] = [];
  for (const g of NAV) for (const p of g.items) out.push({ group: "Chapters", to: p.to, title: p.label, where: g.title });
  for (const s of sections) out.push({ group: "Sections", to: `${s.route}#${s.id}`, title: s.label, where: s.page, hay: s.page });
  for (const s of data.scripts.filter((x) => x.group !== "skill"))
    out.push({ group: "Scripts", to: `/scripts/${s.name}`, title: s.path, mono: true, sub: s.header.split("\n")[0], hay: `${s.header} ${s.functions.join(" ")} ${s.env.join(" ")}` });
  for (const s of data.skills) out.push({ group: "Skills", to: `/skills/${s.name}`, title: s.name, mono: true, sub: s.what, where: s.category, hay: s.description });
  for (const a of data.agents) out.push({ group: "Agents", to: `/agents#${a.name}`, title: a.name, mono: true, sub: a.description });
  for (const m of data.make) out.push({ group: "Make targets", to: `/gates#make`, title: `make ${m.name}`, mono: true, sub: m.does });
  for (const t of data.tests) out.push({ group: "Tests", to: `/gates#tests`, title: t.path, mono: true, sub: t.header.slice(0, 140) });
  return out;
}

const QUICK: SearchItem[] = [
  { group: "Start here", to: "/start", title: "Where to start", where: "Chapter 1" },
  { group: "Start here", to: "/guard", title: "The guard", where: "Chapter 4" },
  { group: "Start here", to: "/change", title: "Changing Bearing", where: "Chapter 14" },
  { group: "Start here", to: "/scripts", title: "Every script", where: "Reference" },
  { group: "Start here", to: "/glossary", title: "Glossary", where: "Reference" },
];

export default function Layout() {
  return (
    <Shell
      site="devguide"
      version={data.version}
      nav={NAV}
      search={buildIndex}
      quick={QUICK}
      searchPlaceholder="Search chapters, scripts, skills and make targets"
      searchEmpty="Try a script (guard), a hook event (Stop) or a variable (BEARING_TRACKER)."
      navFoot={
        <>
          Bearing {data.version}. Built from the kit's own files by <code>bin/gen-devguide.py</code>.
        </>
      }
      footer={
        <>
          Bearing v{data.version}, MIT licensed, source on <a href="https://github.com/Deepta-AI/bearing">GitHub</a>. This guide is generated from the
          repository by <code>bin/gen-devguide.py</code>.
        </>
      }
    />
  );
}
