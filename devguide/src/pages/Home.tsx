import type { ReactNode } from "react";
import { Link } from "react-router";
import { Compass, EVENTS } from "../components/Compass";
import { Terminal } from "../components/Terminal";
import { Page } from "../components/ui";
import { data, skillByName } from "../lib/data";
import { ORDER } from "../lib/nav";
import { RECIPES } from "./Change";
import { SECTION_TONE } from "./Skills";

/* The miniatures on each tile's stage. Every one is drawn from the data the
   linked page shows, so the preview cannot drift from the page. */

const SHORT: Record<string, string> = { SessionStart: "Start", UserPromptSubmit: "Prompt", PostToolUse: "Edit", PreCompact: "Compact", SessionEnd: "End", Stop: "Stop" };

function HookLine() {
  return (
    <div className="mini-line">
      {data.hooks.map((h) => {
        const bash = h.event === "PreToolUse" && h.matcher === "Bash";
        return (
          <span key={`${h.event}-${h.matcher}`} className={bash ? "on" : undefined} style={bash ? { ["--c" as string]: "var(--bad)" } : undefined}>
            <em>{SHORT[h.event] ?? h.matcher}</em>
          </span>
        );
      })}
    </div>
  );
}

function Chapters() {
  return (
    <div className="mini">
      {ORDER.slice(1, 5).map((p) => (
        <div className="r" key={p.to}>
          <span className="m" style={{ marginLeft: 0 }}>
            {p.n}
          </span>
          <span>{p.label}</span>
        </div>
      ))}
    </div>
  );
}

function RecipeList() {
  return (
    <div className="mini">
      {RECIPES.slice(0, 4).map((r, i) => (
        <div className={i ? "r dim" : "r"} key={r.id}>
          <span>{r.title}</span>
          <span className="m">{r.gates.length} gates</span>
        </div>
      ))}
    </div>
  );
}

function Refusal() {
  return (
    <div className="mini-term">
      <div>
        <span className="ps1">$</span> env GIT_TRACE=1 git push
      </div>
      <div className="bad">Bearing blocked 'git push'</div>
      <div className="dim">exit 2</div>
    </div>
  );
}

function SkillCard() {
  const s = skillByName.get("start-task");
  if (!s) return null;
  const total = s.sections.reduce((a, x) => a + x.lines, 0) || 1;
  return (
    <div className="mini-card">
      <b>{s.name}</b>
      <p>{s.what}</p>
      <div className="bar secbar">
        {s.sections.map((x) => (
          <span key={x.title} style={{ width: `${(x.lines / total) * 100}%`, background: SECTION_TONE[x.title] ?? "var(--line-2)" }} />
        ))}
      </div>
    </div>
  );
}

function Rows({ rows }: { rows: [string, string?][] }) {
  return (
    <div className="mini">
      {rows.map(([a, b], i) => (
        <div className="r" key={`${a}-${i}`}>
          <span>{a}</span>
          {b && <span className="m">{b}</span>}
        </div>
      ))}
    </div>
  );
}

function ScriptList() {
  const top = data.scripts
    .filter((s) => s.group !== "skill")
    .sort((a, b) => b.lines - a.lines)
    .slice(0, 4);
  const max = top[0]?.lines ?? 1;
  return (
    <div className="mini">
      {top.map((s) => (
        <div className="r" key={s.path}>
          <span style={{ width: "8.5em", flex: "none" }}>{s.name}</span>
          <span className="bar-in">
            <i style={{ width: `${(s.lines / max) * 100}%` }} />
          </span>
        </div>
      ))}
    </div>
  );
}

function Pills({ items }: { items: string[] }) {
  return (
    <div className="mini-pills">
      {items.map((x) => (
        <span key={x}>{x}</span>
      ))}
    </div>
  );
}

function TemplateTree() {
  const repo = data.templates.filter((t) => t.path.startsWith("repo/")).map((t) => t.path.slice(5));
  const top = [...new Set(repo.map((p) => (p.includes("/") ? `${p.split("/")[0]}/` : p)))];
  const show = [".claude/", ".githooks/", "docs/", "AGENTS.md", "CLAUDE.md", "CODEOWNERS"].filter((p) => top.includes(p));
  return (
    <div className="mini-tree">
      <div className="d">InvoiceService/</div>
      {show.map((p) => (
        <div key={p} className={p.endsWith("/") ? "d" : undefined}>
          {"  "}
          {p}
        </div>
      ))}
    </div>
  );
}

function TestBars() {
  const m = new Map<string, number>();
  for (const t of data.tests) m.set(t.kind, (m.get(t.kind) ?? 0) + 1);
  const rows = [...m.entries()].sort((a, b) => b[1] - a[1]).slice(0, 4);
  const max = rows[0]?.[1] ?? 1;
  return (
    <div className="mini-bars">
      {rows.map(([k, n]) => (
        <div key={k}>
          <span>{k}</span>
          <i style={{ width: `${Math.max(4, (n / max) * 100)}%` }} />
          <b>{n}</b>
        </div>
      ))}
    </div>
  );
}

const WAYS: { to: string; title: string; text: string; stage: ReactNode }[] = [
  { to: "/start", title: "You have an hour", text: "Read chapters 1 to 4 in order. Everything else hangs off them.", stage: <Chapters /> },
  { to: "/change", title: "You need to change something", text: "One recipe per kind of change, with the files it touches and the gates it must pass.", stage: <RecipeList /> },
  {
    to: "/guard",
    title: "Something was blocked",
    text: "A refusal comes from the guard, the settings deny list, a git hook or a gate. The guard chapter shows which.",
    stage: <Refusal />,
  },
];

export default function Home() {
  const c = data.counts;
  const gh = data.gh.flatMap((w) => w.jobs.map((j) => j.name));
  const ciStages = [...new Set(data.ci.map((j) => j.stage || "validate"))];
  const kit: { n: number; part: string; where: string; to: string; note: string; stage: ReactNode }[] = [
    {
      n: c.skills,
      part: "skills",
      where: "plugins/*/skills/*/SKILL.md",
      to: "/skills-work",
      note: c.commandSkills
        ? `${c.commandSkills} typed only, ${c.stackSkills} stack lanes.`
        : `Typed as /bearing:<name> or picked by the model. ${c.stackSkills} are stack lanes.`,
      stage: <SkillCard />,
    },
    {
      n: c.agents,
      part: "subagents",
      where: "plugins/bearing/agents/*.md",
      to: "/agents",
      note: "Forked contexts with fewer tools than the session.",
      stage: <Rows rows={data.agents.slice(0, 4).map((a) => [a.name, a.tools.length === 3 ? "read-only" : `${a.tools.length} tools`])} />,
    },
    { n: c.hooks, part: "hook entries", where: "plugins/bearing/hooks/hooks.json", to: "/session", note: "Each a few lines of shell that hand the event to a kit script.", stage: <HookLine /> },
    {
      n: data.guardRules.length,
      part: "guard rules",
      where: "plugins/bearing/bin/brg-guard",
      to: "/guard",
      note: "The commands an agent may not run.",
      stage: <Rows rows={data.guardRules.filter((r) => r.tool === "git").slice(0, 4).map((r) => [`${r.tool} ${r.pattern}`, "deny"])} />,
    },
    {
      n: c.scripts,
      part: "scripts",
      where: "bin/, plugins/bearing/hooks/scripts/, plugins/*/skills/*/scripts/",
      to: "/scripts",
      note: `${c.scriptLines.toLocaleString("en")} lines of bash and Python.`,
      stage: <ScriptList />,
    },
    { n: c.stacks, part: "stacks", where: "plugins/*/skills/*/templates*/stack.json", to: "/scaffold", note: "What brg-scaffold can build.", stage: <Pills items={data.stacks.map((s) => s.id)} /> },
    { n: c.templates, part: "templates", where: "plugins/bearing/templates/", to: "/scaffold", note: "The files every product repository commits.", stage: <TemplateTree /> },
    {
      n: c.gates,
      part: "gates in make check",
      where: "Makefile",
      to: "/gates",
      note: "Each prints what it counted and fails on zero.",
      stage: <Rows rows={data.check.slice(0, 4).map((g) => [g])} />,
    },
    { n: c.tests, part: "test files", where: "tests/", to: "/gates#tests", note: `Plus ${c.fixtures} fixtures.`, stage: <TestBars /> },
    { n: c.ghJobs, part: "GitHub Actions jobs", where: ".github/workflows/", to: "/gates#ci", note: `In ${c.ghWorkflows} workflows.`, stage: <Pills items={gh} /> },
    { n: c.ciJobs, part: "GitLab CI jobs", where: ".gitlab-ci.yml", to: "/gates#ci", note: "The twin, for a GitLab mirror.", stage: <Pills items={ciStages} /> },
  ];
  return (
    <Page full>
      <header className="hero">
        <span className="eyebrow">Bearing {data.version} / Developer guide</span>
        <h1 className="hero-title">How Bearing works inside</h1>
        <p className="hero-lede">
          Bearing is an open-source (MIT) Claude Code plugin. It gives each stage of building a product a skill, and backs the rules that must hold with code
          instead of prose. This guide shows what runs when, which file decides, and where to make a change safely.
        </p>
        <div className="hero-actions">
          <Link className="btn primary" to="/start">
            Read where to start
          </Link>
          <a className="btn" href="https://github.com/Deepta-AI/bearing">
            github.com/Deepta-AI/bearing
          </a>
        </div>
        <ul className="hero-facts" aria-label="The rules that do not bend">
          <li>
            <b>The agent never pushes.</b> Where you opt a repository in, the Stop hook pushes its task branch.
          </li>
          <li>
            <b>Every gate counts.</b> Each prints what it counted and fails on zero.
          </li>
          <li>
            <b>Everything traces.</b> Commits carry the task id, and the tracker gets a trace comment.
          </li>
        </ul>
      </header>

      <section className="home-panel" aria-labelledby="checkpoints">
        <div className="hp-bar">
          <span className="hp-title" id="checkpoints">
            Session checkpoints
          </span>
          <code className="hp-meta">plugins/bearing/hooks/hooks.json</code>
        </div>
        <div className="hp-body">
          <p className="kicker">Every session passes these {EVENTS.length} checkpoints, in this order. Pick one to see what fires.</p>
          <Compass />
        </div>
      </section>

      <span className="eyebrow">Ways in</span>
      <h2 id="ways-in">Three ways in</h2>
      <div className="tiles ways">
        {WAYS.map((w) => (
          <Link className="tile" to={w.to} key={w.to}>
            <div className="tile-stage" aria-hidden="true">
              {w.stage}
            </div>
            <div className="tile-body">
              <b>{w.title}</b>
              <span>{w.text}</span>
            </div>
          </Link>
        ))}
      </div>

      <span className="eyebrow">Manifest</span>
      <h2 id="manifest">What the kit is made of</h2>
      <p>Counted from the repository when this site was built. No number here is typed by hand.</p>
      <div className="tiles kit">
        {kit.map((k) => (
          <Link className="tile" to={k.to} key={k.part}>
            <div className="tile-stage" aria-hidden="true">
              {k.stage}
            </div>
            <div className="tile-body">
              <b>
                {k.n} {k.part}
              </b>
              <span>{k.note}</span>
              <code className="where">{k.where}</code>
            </div>
          </Link>
        ))}
      </div>

      <span className="eyebrow">Replay</span>
      <h2 id="see-it">See it refuse a push</h2>
      <p>The guard, run by hand against seven commands. The same script checks every Bash call Claude makes in a Bearing repository, in about 20 milliseconds.</p>
      <Terminal id="guard" height={300} />
    </Page>
  );
}
