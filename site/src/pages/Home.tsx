import { DocPage } from "@ui";
import { Link } from "react-router";
import { data } from "../lib/data";

const lines: Record<string, string> = { greenfield: "var(--ok)", bugfix: "var(--gate)", feature: "var(--gsd)", inherited: "var(--sp)", genai: "var(--ok)", site: "var(--gs)" };

/** A thumbnail of a flow: one dot per step on a line, coloured by pack. */
function Mini({ id }: { id: string }) {
  const f = data.flows.find((x) => x.id === id)!;
  const packs: string[] = [];
  const walk = (ns: typeof f.steps) =>
    ns.forEach((n) => {
      if (n.kind === "step") packs.push(n.pack);
      else if (n.kind === "branch") n.options.forEach((o) => walk(o.steps));
    });
  walk(f.steps);
  const col = (p: string) =>
    /superpowers/i.test(p) ? "var(--sp)" : /gstack/i.test(p) ? "var(--gs)" : /gsd/i.test(p) ? "var(--gsd)" : p === "bearing" ? "var(--accent)" : "var(--bi)";
  const n = packs.length;
  return (
    <svg className="mini" viewBox={`0 0 ${n * 12 + 8} 12`} preserveAspectRatio="xMinYMid meet" aria-hidden="true">
      <line x1="4" y1="6" x2={n * 12 + 4} y2="6" stroke={lines[id]} strokeWidth="1" opacity=".45" />
      {packs.map((p, i) => (
        <circle key={i} cx={i * 12 + 8} cy="6" r="3" fill={col(p)} />
      ))}
    </svg>
  );
}

const arrow = (
  <svg className="arr" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden="true">
    <path d="M6 3.5 10.5 8 6 12.5" />
  </svg>
);

export default function Home() {
  const stages = data.stages.length;
  const optional = new Set(data.skills.map((s) => s.plugin ?? "bearing")).size - 1;
  return (
    <DocPage full pager={false}>
      <section className="hero">
        <a className="hero-tag" href="https://github.com/Deepta-AI/bearing">
          <span className="dot" aria-hidden="true" />
          Open source, MIT licensed
          <span className="sep" aria-hidden="true" />
          <span className="muted">github.com/Deepta-AI/bearing</span>
          {arrow}
        </a>
        <h1 data-no-anchor>Which skill to use, at every step of the work</h1>
        <p className="hero-lede">
          Bearing is an open-source workflow for building software with coding agents. For each step, from an idea to a running service, it names
          one skill to run and says what it produces. Installed as a Claude Code plugin or into other harnesses.
        </p>
        <div className="hero-cta">
          <Link className="btn primary" to="/start">
            Set it up
          </Link>
          <Link className="btn" to="/workflow/1">
            See every stage
          </Link>
        </div>
        <ul className="facts">
          <li>
            <b>{data.skills.length}</b>Bearing skills
          </li>
          <li>
            <b>{stages}</b>workflow stages
          </li>
          <li>
            <b>{data.stacks.length}</b>stacks scaffolded
          </li>
          <li>
            <b>{optional + 1}</b>plugins: bearing, and {optional} optional stack plugins
          </li>
        </ul>
      </section>

      <nav className="window" aria-labelledby="stages-h">
        <div className="window-bar">
          <h2 id="stages-h" data-no-anchor>
            Workflow stages
          </h2>
          <span className="muted">From an idea to a service in production. Each stage names one skill per moment.</span>
        </div>
        <ol className="window-list" style={{ ["--rows" as string]: Math.ceil(stages / 2) }}>
          {data.stages.map((s, i) => (
            <li key={s.title}>
              <Link to={`/workflow/${i + 1}`}>
                <i>{String(i + 1).padStart(2, "0")}</i>
                <span>{s.title}</span>
                <small>
                  {s.rows.length} {s.rows.length === 1 ? "moment" : "moments"}
                </small>
                {arrow}
              </Link>
            </li>
          ))}
        </ol>
        <p className="window-foot">
          <b>One skill per step.</b> Each step names one skill. Most are Bearing skills; a few steps call a skill from gstack, Superpowers, GSD or an
          official plugin, and Bearing adds its own gates around it, such as stack checklists or an independent verifier. Every skill page says when
          to use it and where it fits.
        </p>
      </nav>

      <div className="sec-head">
        <h2 id="flows">What are you working on?</h2>
        <p>Each flow walks through the steps in order, with the skill for each and the decisions that change the path.</p>
      </div>
      <div className="scen">
        {data.flows.map((f) => (
          <Link key={f.id} to={`/flows/${f.id}`}>
            <Mini id={f.id} />
            <b>{f.title}</b>
            <span>{f.tagline}</span>
            <small>{f.when}</small>
          </Link>
        ))}
      </div>

      <div className="sec-head">
        <h2 id="more">Or go straight to</h2>
      </div>
      <div className="pick">
        <Link to="/skills">
          <b>The skill catalogue</b>
          <span>Every Bearing skill, what it does and when to use it.</span>
          {arrow}
        </Link>
        <Link to="/start">
          <b>Get started</b>
          <span>Install once per machine, then put a repository on the standard.</span>
          {arrow}
        </Link>
        <Link to="/example">
          <b>A recorded task</b>
          <span>A real build, prompt by prompt, with what each skill produced.</span>
          {arrow}
        </Link>
        <Link to="/rules">
          <b>The rules</b>
          <span>What the workflow never bends, and what enforces it.</span>
          {arrow}
        </Link>
      </div>
    </DocPage>
  );
}
