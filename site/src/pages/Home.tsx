import { DocPage } from "@ui";
import { Link } from "react-router";
import { data } from "../lib/data";

const lines: Record<string, string> = { greenfield: "var(--ok)", bugfix: "var(--gate)", feature: "var(--gsd)", inherited: "var(--sp)" };

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
    <svg className="mini" viewBox={`0 0 ${n * 14 + 8} 20`} preserveAspectRatio="xMinYMid meet" aria-hidden="true">
      <line x1="4" y1="10" x2={n * 14 + 4} y2="10" stroke={lines[id]} strokeWidth="2" opacity=".35" />
      {packs.map((p, i) => (
        <circle key={i} cx={i * 14 + 8} cy="10" r="4" fill={col(p)} />
      ))}
    </svg>
  );
}

export default function Home() {
  const stages = data.stages.length;
  const optional = new Set(data.skills.map((s) => s.plugin ?? "bearing")).size - 1;
  return (
    <DocPage full pager={false}>
      <div className="home-hero">
        <div>
          <h1 data-no-anchor>Which skill to use, at every step of the work</h1>
          <p className="lede">
            Bearing is an open-source workflow for building software with coding agents. For each step, from an idea to a running service, it names
            one skill to run and says what it produces. MIT licensed, installed as a Claude Code plugin or into other
            harnesses, at <a href="https://github.com/Deepta-AI/bearing">github.com/Deepta-AI/bearing</a>.
          </p>
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
          <div className="hero-cta">
            <Link className="btn primary" to="/start">
              Set it up
            </Link>
            <Link className="btn" to="/workflow/1">
              See every stage
            </Link>
          </div>
          <div className="note rule-note">
            <b>One skill per step.</b> Each step names one skill. Most are Bearing skills; a few steps call a skill from gstack, Superpowers, GSD
            or an official plugin, and Bearing adds its own gates around it, such as stack checklists or an independent verifier. Every skill page
            says when to use it and where it fits.
          </div>
        </div>
        <nav className="bearing-line" aria-labelledby="stages-h">
          <h2 id="stages-h" data-no-anchor>
            Workflow stages
          </h2>
          <p>From an idea to a service in production. Each stage names one skill per moment.</p>
          <ol>
            {data.stages.map((s, i) => (
              <li key={s.title}>
                <Link to={`/workflow/${i + 1}`}>
                  <i>{i + 1}</i>
                  <span>{s.title}</span>
                  <small>{s.rows.length}</small>
                </Link>
              </li>
            ))}
          </ol>
        </nav>
      </div>

      <h2 id="flows">What are you working on?</h2>
      <p className="muted" style={{ marginTop: "var(--s2)" }}>
        Each flow walks through the steps in order, with the skill for each and the decisions that change the path.
      </p>
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

      <h2 id="more">Or go straight to</h2>
      <div className="pick" style={{ marginTop: "var(--s4)" }}>
        <Link to="/skills">
          <b>The skill catalogue</b>
          <span>Every Bearing skill, what it does and when to use it.</span>
        </Link>
        <Link to="/start">
          <b>Get started</b>
          <span>Install once per machine, then put a repository on the standard.</span>
        </Link>
        <Link to="/example">
          <b>A recorded task</b>
          <span>A real build, prompt by prompt, with what each skill produced.</span>
        </Link>
        <Link to="/rules">
          <b>The rules</b>
          <span>What the workflow never bends, and what enforces it.</span>
        </Link>
      </div>
    </DocPage>
  );
}
