import { Link } from "react-router";
import { Compass } from "../components/Compass";
import { Terminal } from "../components/Terminal";
import { Page } from "../components/ui";
import { data } from "../lib/data";

const WAYS: { to: string; title: string; text: string; meta: string }[] = [
  {
    to: "/start",
    title: "You have an hour",
    text: "Read chapters 1 to 4 in order: where things live, the five layers, one session event by event, and the guard. Everything else hangs off those.",
    meta: "Where to start, then Next at the foot of each page",
  },
  {
    to: "/change",
    title: "You need to change something",
    text: "Recipes for a new skill, a script, a stack, a tracker, a harness and a guard rule, each with the gates it must pass and the tests to add.",
    meta: "Changing Bearing",
  },
  {
    to: "/guard",
    title: "Something was blocked",
    text: "Every refusal comes from one of four places: the guard, the settings deny list, a git hook or a gate. The guard chapter shows how to tell which.",
    meta: "The guard, then Gates, tests and CI",
  },
];

export default function Home() {
  const c = data.counts;
  const manifest: [string, number | string, string, string, string][] = [
    ["Skills", c.skills, "plugins/*/skills/*/SKILL.md", "/skills-work", c.commandSkills
      ? `${c.commandSkills} typed only, ${c.skills - c.commandSkills} also picked by the model, ${c.stackSkills} stack lanes`
      : `every one picked by the model or typed as /bearing:<name>; ${c.stackSkills} stack lanes`],
    ["Subagents", c.agents, "plugins/bearing/agents/*.md", "/agents", "bearing:<name>, forked contexts with fewer tools than the session"],
    ["Hook events", c.hooks, "plugins/bearing/hooks/hooks.json", "/session", "each a few lines of shell over one guard script"],
    ["Guard rules", data.guardRules.length, "plugins/bearing/bin/brg-guard", "/guard", "the verbs an agent may not run"],
    ["Scripts", c.scripts, "bin/, plugins/bearing/hooks/scripts/, plugins/*/skills/*/scripts/", "/scripts", `${c.scriptLines.toLocaleString("en")} lines of bash and Python`],
    ["Stacks", c.stacks, "plugins/*/skills/*/templates*/stack.json", "/scaffold", "what brg-scaffold can build"],
    ["Repository templates", c.templates, "templates/", "/scaffold", "the files every product repository commits"],
    ["Gates in make check", c.gates, "Makefile", "/gates", "each prints what it counted and fails on zero"],
    ["Test files", c.tests, "tests/", "/gates", `plus ${c.fixtures} fixtures`],
    ["GitHub Actions jobs", c.ghJobs, ".github/workflows/", "/gates", `in ${c.ghWorkflows} workflows: checks, scaffolds, bash 3.2, macOS, the two sites`],
    ["GitLab CI jobs", c.ciJobs, ".gitlab-ci.yml", "/gates", "the twin, for a GitLab mirror"],
  ];
  return (
    <Page full>
      <header className="hero">
        <p className="hero-kicker">
          <span className="tag">Bearing {data.version}</span>
          <span>The developer guide</span>
        </p>
        <h1 className="hero-title">How Bearing works inside</h1>
        <p className="hero-lede">
          Bearing is an open-source (MIT) Claude Code plugin that gives every stage of a product a skill, and makes the rules that must not bend physical
          instead of polite. This guide is its service manual: what runs when, which file decides, and where to make a change without breaking the rest.
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
            <b>Everything traces.</b>
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
          <p className="kicker">Every Bearing session passes the same six checkpoints. Pick one to see what fires.</p>
          <Compass />
        </div>
      </section>

      <h2 id="ways-in">Three ways in</h2>
      <div className="ways">
        {WAYS.map((w) => (
          <Link className="way" to={w.to} key={w.to}>
            <h3>{w.title}</h3>
            <p>{w.text}</p>
            <span className="meta">
              {w.meta}
              <svg viewBox="0 0 16 16" aria-hidden="true">
                <path d="M6 3.5 10.5 8 6 12.5" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </span>
          </Link>
        ))}
      </div>

      <h2 id="manifest">What the kit is made of</h2>
      <p>Counted from the repository when this site was built. Nothing on this page is typed by hand.</p>
      <ul className="manifest-grid">
        {manifest.map(([part, n, where, to, note]) => (
          <li key={part}>
            <Link to={to}>
              <span className="mg-n">{n}</span>
              <span className="mg-part">{part}</span>
              <span className="mg-note">{note}</span>
              <code className="mg-where">{where}</code>
            </Link>
          </li>
        ))}
      </ul>

      <h2 id="see-it">See it refuse a push</h2>
      <p>
        A recording of the guard run by hand against seven commands. The same script answers every Bash call Claude makes in a Bearing repository, in
        about 20 milliseconds.
      </p>
      <Terminal id="guard" height={300} />
    </Page>
  );
}
