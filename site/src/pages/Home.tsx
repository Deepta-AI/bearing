import { DocPage } from "@ui";
import { Link } from "react-router";
import { data, packKey, skillByName, type Flow, type FlowStep } from "../lib/data";
import { catLabel } from "../lib/nav";

const lines: Record<string, string> = { greenfield: "var(--ok)", bugfix: "var(--gate)", feature: "var(--gsd)", inherited: "var(--sp)", genai: "var(--ok)", site: "var(--gs)" };
const packColour = (p: string) => {
  const k = packKey(p);
  return k === "bearing" ? "var(--accent)" : `var(--${k})`;
};

/** Every step of a flow in reading order, branches included. */
function stepsOf(f: Flow): FlowStep[] {
  const out: FlowStep[] = [];
  const walk = (ns: Flow["steps"]) =>
    ns.forEach((n) => {
      if (n.kind === "step") out.push(n);
      else if (n.kind === "branch") n.options.forEach((o) => walk(o.steps));
    });
  walk(f.steps);
  return out;
}

/** A thumbnail of a flow: one dot per step on a line, coloured by pack. */
function Mini({ flow, steps }: { flow: Flow; steps: FlowStep[] }) {
  const n = steps.length;
  return (
    <svg className="mini" viewBox={`0 0 ${n * 12 + 8} 12`} preserveAspectRatio="xMinYMid meet" aria-hidden="true">
      <line x1="4" y1="6" x2={n * 12 + 4} y2="6" stroke={lines[flow.id]} strokeWidth="1" opacity=".45" />
      {steps.map((s, i) => (
        <circle key={i} cx={i * 12 + 8} cy="6" r="3" fill={packColour(s.pack)} />
      ))}
    </svg>
  );
}

/** The stage of a flow tile: the dots line, then its first three steps. */
function FlowThumb({ flow }: { flow: Flow }) {
  const steps = stepsOf(flow);
  return (
    <div className="thumb" aria-hidden="true">
      <Mini flow={flow} steps={steps} />
      <ol className="thumb-rows">
        {steps.slice(0, 3).map((s) => (
          <li key={s.id} style={{ ["--c" as string]: packColour(s.pack) }}>
            <i className="dot" />
            <span>{s.title}</span>
            <code>{s.skill}</code>
          </li>
        ))}
      </ol>
      <small>{steps.length} steps</small>
    </div>
  );
}

/** The stage of the catalogue tile: one real skill as its catalogue entry, over the category count. */
function SkillThumb() {
  const s = skillByName.get("merge-request") ?? data.skills[0];
  return (
    <div className="thumb" aria-hidden="true">
      <div className="thumb-card">
        <div className="head">
          <span className="skillname">{s.name}</span>
          <span className="tag">{catLabel(s.category)}</span>
        </div>
        <p>{s.what}.</p>
        <code>/{s.plugin ?? "bearing"}:{s.name}</code>
      </div>
      <div className="thumb-chips">
        {data.categories.slice(0, 4).map((c) => (
          <span key={c}>{catLabel(c)}</span>
        ))}
        <span>+{data.categories.length - 4}</span>
      </div>
    </div>
  );
}

/** The stage of the recorded-task tile: the first steps of the recording. */
function TaskThumb() {
  const steps = [...data.walkthrough.matchAll(/^## Step\s+(\d+):?\s*(.*)$/gm)].map((m) => ({ n: m[1], t: m[2] }));
  return (
    <div className="thumb" aria-hidden="true">
      <ol className="thumb-rows num">
        {steps.slice(0, 4).map((s) => (
          <li key={s.n}>
            <i>{s.n}</i>
            <span>{s.t}</span>
          </li>
        ))}
      </ol>
      <small>{steps.length} steps recorded</small>
    </div>
  );
}

/** The stage of the default-files tile: the repository's top level, folders with their file count. */
function FileThumb() {
  const scope = data.defaultFiles.find((s) => s.id === "repository") ?? data.defaultFiles[0];
  const top: { name: string; n: number }[] = [];
  for (const f of scope.files) {
    const path = f.path.split(" ")[0];
    const i = path.indexOf("/");
    const name = i < 0 ? path : path.slice(0, i + 1);
    const hit = top.find((t) => t.name === name);
    if (hit) hit.n++;
    else top.push({ name, n: 1 });
  }
  return (
    <div className="thumb" aria-hidden="true">
      <ul className="thumb-tree">
        {top.slice(0, 6).map((t) => (
          <li key={t.name} className={t.name.endsWith("/") ? "dir" : undefined}>
            <span>{t.name}</span>
            {t.name.endsWith("/") && <small>{t.n}</small>}
          </li>
        ))}
      </ul>
      <small>
        {scope.files.length} files in every repository
      </small>
    </div>
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
        <span className="eyebrow">Bearing handbook, v{data.version}</span>
        <h1 data-no-anchor>Which skill to use, at every step of the work</h1>
        <p className="hero-lede">
          Bearing is an open-source workflow for building software with coding agents. For each step, from an idea to a running service, it names one
          skill and what that skill produces. It installs as a Claude Code plugin or into other harnesses.
        </p>
        <div className="hero-cta">
          <Link className="btn primary" to="/start">
            Set it up
          </Link>
          <Link className="btn" to="/workflow/1">
            See every stage
          </Link>
          <a className="btn" href="https://github.com/Deepta-AI/bearing">
            Source on GitHub
            {arrow}
          </a>
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
            <b>{optional + 1}</b>plugins: bearing and {optional} optional ones
          </li>
        </ul>
      </section>

      <nav className="window" aria-labelledby="stages-h">
        <div className="window-bar">
          <h2 id="stages-h" data-no-anchor>
            Workflow stages
          </h2>
          <span className="muted">From an idea to a service in production.</span>
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
          <b>One skill per step.</b> Most steps run a Bearing skill. A few call a skill from gstack, Superpowers, GSD or an official plugin, and Bearing
          adds its own gates around it, such as stack checklists or an independent verifier.
        </p>
      </nav>

      <div className="sec-head">
        <span className="eyebrow">Flows</span>
        <h2 id="flows">What are you working on?</h2>
        <p>Pick the flow that matches your work. Each one lists the steps in order, the skill for each, and the questions that change the path.</p>
      </div>
      <div className="tiles">
        {data.flows.map((f) => (
          <Link key={f.id} className="tile" to={`/flows/${f.id}`}>
            <div className="tile-stage">
              <FlowThumb flow={f} />
            </div>
            <div className="tile-body">
              <b>{f.title}</b>
              <span>{f.tagline}</span>
            </div>
          </Link>
        ))}
      </div>

      <div className="sec-head">
        <span className="eyebrow">Reference</span>
        <h2 id="more">Or go straight to</h2>
      </div>
      <div className="tiles">
        <Link className="tile" to="/skills">
          <div className="tile-stage">
            <SkillThumb />
          </div>
          <div className="tile-body">
            <b>The skill catalogue</b>
            <span>Every Bearing skill: what it does and when to use it.</span>
          </div>
        </Link>
        <Link className="tile" to="/example">
          <div className="tile-stage">
            <TaskThumb />
          </div>
          <div className="tile-body">
            <b>A recorded task</b>
            <span>A real build, prompt by prompt, with each skill's report.</span>
          </div>
        </Link>
        <Link className="tile" to="/files">
          <div className="tile-stage">
            <FileThumb />
          </div>
          <div className="tile-body">
            <b>Default files</b>
            <span>What the installer and onboard-repo write, file by file.</span>
          </div>
        </Link>
      </div>
      <p className="muted home-also">
        Also: <Link to="/rules">the rules</Link> the workflow never bends, and <Link to="/faq">troubleshooting</Link>.
      </p>
    </DocPage>
  );
}
