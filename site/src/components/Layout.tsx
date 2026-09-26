import { Shell, type SearchItem } from "@ui";
import sections from "virtual:sections";
import { data } from "../lib/data";
import { NAV, ORDER } from "../lib/nav";

/** Everything search can find: pages and their sections, skills, stages, flow steps and default files. */
function buildIndex(): SearchItem[] {
  const out: SearchItem[] = [];
  for (const p of ORDER) out.push({ group: "Pages", to: p.to, title: p.label, where: "Page" });
  for (const s of sections) out.push({ group: "Sections", to: `${s.route}#${s.id}`, title: s.label, where: s.page, hay: s.page });
  for (const s of data.skills)
    out.push({ group: "Skills", to: `/skills/${s.name}`, title: s.name, mono: true, sub: s.what, where: s.category, hay: `${s.when} ${s.phrases.join(" ")}` });
  data.stages.forEach((st, i) =>
    st.rows.forEach((r) =>
      out.push({ group: "Workflow stages", to: `/workflow/${i + 1}`, title: r.stage, sub: `${r.skill}: ${r.output}`, where: st.title, hay: `${st.title} ${r.from}` }),
    ),
  );
  const visit = (fid: string, ftitle: string, nodes: (typeof data.flows)[number]["steps"]) => {
    for (const n of nodes) {
      if (n.kind === "step")
        out.push({ group: "Flow steps", to: `/flows/${fid}?step=${n.id}`, title: n.title, sub: n.skill, where: ftitle, hay: `${ftitle} ${n.does}` });
      else if (n.kind === "branch") n.options.forEach((o) => visit(fid, ftitle, o.steps));
    }
  };
  data.flows.forEach((f) => visit(f.id, f.title, f.steps));
  for (const sc of data.defaultFiles)
    for (const f of sc.files)
      out.push({ group: "Default files", to: `/files?scope=${sc.id}&file=${encodeURIComponent(f.path)}`, title: f.path, mono: true, sub: f.purpose, where: sc.title, hay: f.group ?? "" });
  return out;
}

const QUICK: SearchItem[] = [
  { group: "Start here", to: "/start", title: "Install and set up", where: "Get started" },
  { group: "Start here", to: "/workflow/1", title: "Every workflow stage, in order", where: "Workflow stages" },
  { group: "Start here", to: "/skills", title: "All skills by the part of the work", where: "Skills" },
  { group: "Start here", to: "/flows/feature", title: "Add a feature, step by step", where: "Flows" },
  { group: "Start here", to: "/faq", title: "Troubleshooting", where: "Reference" },
];

export default function Layout() {
  return (
    <Shell
      site="handbook"
      version={data.version}
      nav={NAV}
      search={buildIndex}
      quick={QUICK}
      searchPlaceholder="Search skills, stages, flows and pages"
      searchEmpty='Try a stage ("verify"), a stack ("go") or a phrase ("prepare the MR").'
      footer={
        <>
          Bearing v{data.version}, MIT licensed, source on <a href="https://github.com/Deepta-AI/bearing">GitHub</a>. Generated from the skills in the
          repository; regenerate with <code>make docs</code>.
        </>
      }
    />
  );
}
