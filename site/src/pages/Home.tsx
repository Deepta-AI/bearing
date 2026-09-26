import { Link } from "react-router";
import { data } from "../lib/data";

const lines: Record<string, string> = { greenfield: "var(--jade)", bugfix: "var(--warn)", feature: "var(--gsd)", inherited: "var(--sp)" };

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
    /superpowers/i.test(p) ? "var(--sp)" : /gstack/i.test(p) ? "var(--gs)" : /gsd/i.test(p) ? "var(--gsd)" : p === "bearing" ? "var(--jade)" : "var(--bi)";
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
  const cmp = Object.values(data.comparisons);
  const stronger = cmp.filter((c) => c.verdict === "bearing-stronger").length;
  return (
    <div className="page full">
      <article>
        <div className="home-hero">
          <div>
            <h1>Which skill to use, at every step of the work</h1>
            <p className="lede">
              Bearing is the team's workflow for building software with coding agents. For each step, from an idea to a running service, it names the
              strongest skill available, whichever pack it comes from, and says why.
            </p>
            <div className="facts">
              <span>
                <b>{data.skills.length}</b>Bearing skills
              </span>
              <span>
                <b>{stages}</b>workflow stages
              </span>
              <span>
                <b>{data.stacks.length}</b>stacks scaffolded
              </span>
              <span>
                <b>{stronger}</b>beat their best installed alternative
              </span>
            </div>
            <div style={{ display: "flex", gap: "var(--s3)", flexWrap: "wrap" }}>
              <Link className="btn primary" to="/start">
                Set it up
              </Link>
              <Link className="btn" to="/workflow">
                See every stage
              </Link>
            </div>
          </div>
          <div className="note" style={{ margin: 0 }}>
            <b>The rule behind every recommendation.</b> The strongest skill for a step is the one used. A Bearing skill is named only where nothing
            installed does that step better; where gstack, Superpowers, GSD or an official plugin is stronger, the workflow uses it and Bearing
            adds only what it lacks, such as the team's checklists or an independent verifier. Every skill page shows the comparison.
          </div>
        </div>

        <h2>What are you working on?</h2>
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

        <h2>Or go straight to</h2>
        <div className="pick" style={{ marginTop: "var(--s4)" }}>
          <Link to="/skills">
            <b>The skill catalogue</b>
            <span>Every Bearing skill, its best alternative and the verdict.</span>
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
      </article>
    </div>
  );
}
