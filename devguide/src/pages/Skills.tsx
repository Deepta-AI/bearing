import { useMemo, useState } from "react";
import { Link, useParams } from "react-router";
import { Code, H2, Note, Page, Rich, S } from "../components/ui";
import { CATEGORY_LABEL, data, skillByName, type Skill } from "../lib/data";

const SECTION_TONE: Record<string, string> = {
  Inputs: "var(--sea)",
  Steps: "var(--brass)",
  "Output contract": "var(--jade)",
  Gotchas: "var(--signal)",
  "When this skill is active": "var(--sea)",
  Layout: "var(--brass)",
  "Rules that matter most": "var(--brass)",
  Commands: "var(--jade)",
};

function SectionBar({ s }: { s: Skill }) {
  const total = s.sections.reduce((a, x) => a + x.lines, 0) || 1;
  return (
    <div>
      <div className="bar secbar" role="img" aria-label={`Sections by length: ${s.sections.map((x) => `${x.title} ${x.lines} lines`).join(", ")}`}>
        {s.sections.map((x) => (
          <span key={x.title} style={{ width: `${(x.lines / total) * 100}%`, background: SECTION_TONE[x.title] ?? "var(--rule-2)" }} title={`${x.title}: ${x.lines} lines`} />
        ))}
      </div>
      <div className="seclegend">
        {s.sections.map((x) => (
          <span key={x.title}>
            <i style={{ background: SECTION_TONE[x.title] ?? "var(--rule-2)" }} />
            {x.title} <small>{x.lines}</small>
          </span>
        ))}
      </div>
    </div>
  );
}

function Lifecycle() {
  const steps = [
    ["In every session", "Name and description only, inside a listing capped at about 1% of the context window; past the cap some skills show by name only."],
    ["Triggered", "You type /bearing:start-task, or your words match a description's quoted phrases."],
    ["Body loads", "SKILL.md below the frontmatter enters the context; allowed-tools now bound the session's tool calls for this skill."],
    ["Inputs resolved", "Each input from its first place, else its fallback, else one question. Never another skill as a prerequisite."],
    ["Steps run", "Reading references/ only when a step says so; calling bin/ scripts through granted Bash patterns."],
    ["Output contract", "A fixed block with counts, so a person or a calling skill can check the result without reading the transcript."],
  ];
  return (
    <ol className="lifecycle wide" aria-label="How a skill runs">
      {steps.map(([t, d], i) => (
        <li key={t} style={{ animationDelay: `${i * 90}ms` }}>
          <b>{t}</b>
          <span>{d}</span>
        </li>
      ))}
    </ol>
  );
}

export function SkillsWork() {
  const sk = data.skills;
  const extraCounts = useMemo(() => {
    const m = new Map<string, number>();
    for (const s of sk) for (const k of Object.keys(s.extra)) m.set(k, (m.get(k) ?? 0) + 1);
    return [...m.entries()].sort((a, b) => b[1] - a[1]);
  }, [sk]);
  const forked = sk.filter((s) => s.extra.context === "fork");
  const decisions = sk.filter((s) => s.tools.includes("Skill"));
  const withArgs = sk.filter((s) => s.args).length;
  const byCat = useMemo(() => {
    const m = new Map<string, number>();
    for (const s of sk) m.set(s.category, (m.get(s.category) ?? 0) + 1);
    return [...m.entries()].sort((a, b) => b[1] - a[1]);
  }, [sk]);
  const max = Math.max(...byCat.map(([, n]) => n));
  const skillScripts = data.scripts.filter((s) => s.group === "skill");
  const example = skillByName.get("start-task")!;
  return (
    <Page
      title="How skills work"
      lede={`A skill is one Markdown file with a frontmatter block, read by two audiences: Claude Code reads the frontmatter to decide when the skill may run and what it may touch; the model reads the body to know how. Bearing has ${sk.length}, and lints every one of them the same way.`}
      toc={[
        { id: "anatomy", label: "Anatomy of SKILL.md" },
        { id: "frontmatter", label: "The frontmatter" },
        { id: "lifecycle", label: "From trigger to output" },
        { id: "kinds", label: "Step skills and stack skills" },
        { id: "sections", label: "The section contract" },
        { id: "tools", label: "allowed-tools and lint-tools" },
        { id: "files", label: "references, templates, scripts" },
        { id: "forks", label: "Forked skills" },
        { id: "evals", label: "Evals" },
        { id: "packs", label: "One skill per stage" },
        { id: "map", label: "Where the skills are" },
      ]}
      sources={["plugins/bearing/skills/new-skill/templates/SKILL.template.md", "bin/lint-skill-tools.py", "bin/lint-skill-evals.py", "bin/skill-evals.py", "bin/gen-guide.py"]}
    >
      <H2 id="anatomy">Anatomy of SKILL.md</H2>
      <p>A real skill, shortened, with what each part is for. New skills start from <code>plugins/bearing/skills/new-skill/templates/SKILL.template.md</code>, which has the same shape.</p>
      <div className="anno wide">
        <pre className="anno-src">{`---
name: start-task
description: 'Starts work on a ticket: creates the branch from
  the right base with the task id, writes state and progress
  notes, restates the criteria. Use when asked to "start
  TASK-142", "pick up this ticket" or "create a branch".'
argument-hint: "<TASK-ID> [PascalName] [--type feature|...]"
allowed-tools: Read, Write, Edit, Grep, Glob,
  Bash(bash *bin/brg-tracker *), Bash(git status:*),
  Bash(git switch:*), Bash(bash *bin/brg-state-path*),
  Bash(python3 *skills/session-handoff/scripts/progress.py*), ...
---

# start-task

One paragraph: what it is for, and what it is not.

## Inputs
- Task id: $1; if absent, one question; nothing: stop.

## Steps
1. ...

## Output contract
\`\`\`
Branch: feature/TASK-142-InvoiceTotals
...
\`\`\`

## Gotchas
- the ways this goes wrong`}</pre>
        <ol className="anno-notes">
          <li><b>name</b> must equal the folder. <code>lint-skills</code> checks it.</li>
          <li><b>description</b> is the trigger. The job first, then "Use when" and at least two quoted phrases, 220 characters at most, because the start is what survives a shortened listing.</li>
          <li><b>argument-hint</b> shows in the slash menu when you type <code>/bearing:start-task</code>. No Bearing skill sets <code>disable-model-invocation</code>: it would hide the skill from the model entirely.</li>
          <li><b>allowed-tools</b> is least privilege. Scripts appear as exact Bash patterns, never a bare <code>Bash</code> or <code>bash:*</code>.</li>
          <li><b>Inputs</b> is the independence contract: each input's first place and its fallback.</li>
          <li><b>Output contract</b> is a fixed block with counts, so a caller can check the result.</li>
          <li><b>Gotchas</b> are the most valuable lines: the mistakes a capable model still makes here.</li>
        </ol>
      </div>
      <p>
        See the real one: <S name={example.name} /> ({example.lines} lines, {example.files.length} files).
      </p>

      <H2 id="frontmatter">The frontmatter</H2>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>Key</th>
              <th>Skills using it</th>
              <th>Read by</th>
            </tr>
          </thead>
          <tbody>
            <tr><td><code>name</code></td><td>{sk.length}</td><td>Claude Code; lint-skills checks it equals the folder</td></tr>
            <tr><td><code>description</code></td><td>{sk.length}</td><td>the model, to decide when to trigger; lint-skills</td></tr>
            <tr><td><code>allowed-tools</code></td><td>{sk.filter((s) => s.tools.length).length}</td><td>Claude Code, while the skill runs; lint-tools</td></tr>
            <tr><td><code>disable-model-invocation</code></td><td>{data.counts.commandSkills}</td><td>Claude Code: hides the skill from the model</td></tr>
            <tr><td><code>argument-hint</code></td><td>{withArgs}</td><td>the slash-command menu</td></tr>
            {extraCounts.map(([k, n]) => (
              <tr key={k}>
                <td><code>{k}</code></td>
                <td>{n}</td>
                <td>{k === "context" ? "Claude Code: fork runs the skill in a subagent" : k === "agent" ? "Claude Code: which subagent a forked skill runs under" : "Claude Code"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <H2 id="lifecycle">From trigger to output</H2>
      <Lifecycle />

      <H2 id="kinds">Step skills and stack skills</H2>
      <div className="cols">
        <div className="card">
          <h4>Two ways in ({sk.length})</h4>
          <p>
            Every skill can be typed as <code>/bearing:&lt;name&gt;</code> and picked by the model when your words match. Side effects stay safe because the
            guard and the settings refuse what a person must do (push, merge, tag, deploy), not because the skill is hidden.
            {data.counts.commandSkills ? ` ${data.counts.commandSkills} set disable-model-invocation and are typed only.` : ""}
          </p>
        </div>
        <div className="card">
          <h4>Why names and descriptions are short</h4>
          <p>
            Every description is paid for in every session, and Claude Code caps the listing. So each name says its job (<code>definition-of-done</code>, not{" "}
            <code>dod</code>), and each description leads with the job and its phrases in 220 characters or fewer, tuned against near-miss prompts.
          </p>
        </div>
        <div className="card">
          <h4>Stack skills ({data.counts.stackSkills})</h4>
          <p>
            Conventions for one language or platform (<S name="go" />, <S name="react" />). Different sections: When this skill is active, Layout, On a
            foreign layout, Rules that matter most, Commands. Their <code>templates/</code> are what <S name="brg-scaffold" /> builds from.
          </p>
        </div>
      </div>

      <H2 id="sections">The section contract</H2>
      <p>
        <code>make lint-skills</code> enforces the headings. Step skills need Inputs, Steps, Output contract and Gotchas; stack skills need their own five and
        Gotchas. Each exists for a reason learned the hard way:
      </p>
      <ul>
        <li>
          <strong>Inputs with fallbacks</strong>, because a skill that stops since another skill has not run is broken. Every input names where it looks first,
          where next, and the one question it asks when both are empty.
        </li>
        <li>
          <strong>Steps</strong> that name tools and files, not intentions. A step the model cannot check is a step it will skip.
        </li>
        <li>
          <strong>Output contract</strong> with counts, because "done" is not evidence. A person, or the skill that called this one, checks the block instead of the transcript.
        </li>
        <li>
          <strong>Gotchas</strong>, because the obvious steps are what the model already does. The value of a skill is in its gotchas.
        </li>
      </ul>
      <p>The shape of every skill, drawn to scale: the colours are the four sections, the width is how many lines each holds.</p>
      <div className="secgrid wide">
        {["start-task", "branch-review", "prd", "go", "tech-decision", "autopilot"].map((n) => {
          const s = skillByName.get(n);
          return s ? (
            <Link key={n} to={`/skills/${n}`} className="secitem">
              <code>{n}</code>
              <SectionBar s={s} />
            </Link>
          ) : null;
        })}
      </div>

      <H2 id="tools">allowed-tools and lint-tools</H2>
      <p>
        While a skill runs, its <code>allowed-tools</code> are what it may use without asking. Bearing treats that list as a contract with two checks:
      </p>
      <ul>
        <li>
          <code>lint-skills</code> rejects a blanket <code>Bash(bash:*)</code> or <code>Bash(git -C:*)</code>, and requires <code>Skill</code> in any skill that
          runs the decision protocol (the "Decisions first" block, which calls <S name="tech-decision" />). {decisions.length} skills carry <code>Skill</code>.
        </li>
        <li>
          <code>lint-tools</code> (<S name="lint-skill-tools.py" />) reads every command in a skill's Inputs, Steps and Commands, inline and fenced, splits it
          on pipes and <code>&amp;&amp;</code>, and checks that some grant covers each program. Commands the guard blocks anyway (push, tag, publish) are
          exempt, and so are commands the skill only prints for you, which must be listed with a reason in <code>bin/lint-skill-tools.allow</code>.
        </li>
      </ul>
      <Code cap="bin/lint-skill-tools.allow: skill | command prefix | why no grant is needed">{`api-versioning|make test-contracts|a target the skill adds to the Makefile
license-compliance|npm ci|named as a reproducible-build flag in the release notes`}</Code>

      <H2 id="files">references, templates, scripts</H2>
      <p>A skill folder holds up to three kinds of file beside SKILL.md, and the lint checks that every backticked path in the body exists.</p>
      <ul>
        <li>
          <strong>references/</strong> are read on demand: checklists, guidelines, decision catalogues. They cost nothing until a step says "read".
        </li>
        <li>
          <strong>templates/</strong> are copied: a PRD skeleton, a runbook, and for stack skills the whole repository layer with a <code>stack.json</code>.
          A template a skill fills lives in its own folder, never only under <code>plugins/bearing/templates/repo/</code>, so the skill works alone.
        </li>
        <li>
          <strong>scripts/</strong> are checks the model must not do by eye. There are {skillScripts.length}, for example{" "}
          {skillScripts.slice(0, 5).map((s, i) => (
            <span key={s.path}>
              {i ? ", " : ""}
              <Link to={`/skills/${s.skill}`}>
                <code>{s.path.replace(/^plugins\/[^/]+\/skills\//, "")}</code>
              </Link>
            </span>
          ))}
          . Each prints a count and fails on empty input.
        </li>
      </ul>

      <H2 id="forks">Forked skills</H2>
      <p>
        {forked.length} skills set <code>context: fork</code> and an <code>agent</code>, so they run in that subagent's context with its tools instead of the
        session's: {forked.map((s, i) => (
          <span key={s.name}>
            {i ? ", " : ""}
            <S name={s.name} /> under <code>{s.extra.agent}</code>
          </span>
        ))}
        . The doc writer has no shell and edits under <code>docs/</code> only, so these skills can be trusted with prose without being trusted with the
        repository.
      </p>

      <H2 id="evals">Evals</H2>
      <p>
        A skill that does not pass more of its cases than a no-skill baseline is prose the model already follows. Each measured skill has <code>evals/&lt;name&gt;/evals.json</code>{" "}
        (kept outside the skill folder, so a run that follows the skill never reads its own grading) in skill-creator's schema: prompts, fixture repositories
        under <code>files/</code>, and expectations a grader can check.
      </p>
      <p>
        {data.counts.evals} skills have evals; {data.evalsPending.length} predate the rule and sit on <code>evals/.pending</code>. <code>lint-evals</code> fails a
        new skill without evals, and fails a pending row for a skill that now has them, so the list only shrinks. <S name="skill-evals.py" /> prepares blind
        arms (with the skill and with nothing), then unblinds and measures after grading; results stay in the maintainer's <code>.scratch/</code>.
      </p>
      <div className="bar" style={{ height: 12 }} role="img" aria-label={`${data.counts.evals} of ${data.counts.skills} skills have evals`}>
        <span style={{ width: `${(data.counts.evals / data.counts.skills) * 100}%`, background: "var(--jade)" }} />
      </div>
      <p className="barcap">
        {data.counts.evals} of {data.counts.skills} skills measured
      </p>

      <H2 id="packs">One skill per stage</H2>
      <p>
        <code>STAGES</code> in <code>bin/gen-guide.py</code> names one skill per stage row, whatever pack provides it. Where a row names another pack's
        skill, Bearing calls it and adds its own gates (as <S name="branch-review" /> runs gstack's review and adds independent verification). Every
        name a row uses must be a Bearing skill or appear in <code>docs/known-skills.txt</code>.
      </p>
      <Note title="Changing a stage's skill">
        <p>
          Edit <code>STAGES</code> in <code>bin/gen-guide.py</code>, run <code>make docs</code>, and commit the regenerated{" "}
          <code>docs/WORKFLOW.md</code> and site data. <code>lint-docs</code> fails if you forget.
        </p>
      </Note>

      <H2 id="map">Where the skills are</H2>
      <div className="catbars wide">
        {byCat.map(([c, n]) => (
          <Link key={c} to={`/skills?cat=${encodeURIComponent(c)}`} className="catbar">
            <span className="cb-l">{CATEGORY_LABEL[c] ?? c}</span>
            <span className="cb-b">
              <span style={{ width: `${(n / max) * 100}%` }} />
            </span>
            <span className="cb-n">{n}</span>
          </Link>
        ))}
      </div>
    </Page>
  );
}

export function Skills() {
  const params = new URLSearchParams(typeof window !== "undefined" ? window.location.search : "");
  const [cat, setCat] = useState(params.get("cat") ?? "");
  const [kind, setKind] = useState("");
  const [q, setQ] = useState("");
  const cats = useMemo(() => [...new Set(data.skills.map((s) => s.category))].sort(), []);
  const list = data.skills.filter(
    (s) =>
      (!cat || s.category === cat) &&
      (!kind || (kind === "command" ? s.invocation === "command" : kind === "auto" ? s.invocation === "auto" : kind === "stack" ? s.kind === "stack" : s.evals)) &&
      (!q || `${s.name} ${s.description}`.toLowerCase().includes(q.toLowerCase())),
  );
  return (
    <Page full title="Every skill" lede="The anatomy of each skill as it is on disk: its frontmatter, its sections to scale, its inputs, steps and gotchas, and every file in its folder.">
      <div className="filters">
        <input type="search" placeholder="Filter by name or words" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Filter skills" />
        {[
          ["", "All"],
          ...(data.counts.commandSkills ? [["command", "Typed only"]] : []),
          ["stack", "Stack"],
          ["evals", "Measured"],
        ].map(([k, l]) => (
          <button key={k} type="button" aria-pressed={kind === k} onClick={() => setKind(k)}>
            {l}
          </button>
        ))}
      </div>
      <div className="filters">
        <button type="button" aria-pressed={cat === ""} onClick={() => setCat("")}>
          Every category
        </button>
        {cats.map((c) => (
          <button key={c} type="button" aria-pressed={cat === c} onClick={() => setCat(c)}>
            {CATEGORY_LABEL[c] ?? c}
          </button>
        ))}
        <span className="count">{list.length} shown</span>
      </div>
      <div className="skillgrid">
        {list.map((s) => (
          <Link key={s.name} to={`/skills/${s.name}`} className="card skillcard">
            <h4>
              <code>{s.name}</code>
            </h4>
            <p>{s.what}</p>
            <SectionBar s={s} />
            <div className="chips">
              {s.invocation === "command" && <span className="chip brass">typed only</span>}
              {s.kind === "stack" && <span className="chip">stack</span>}
              <span className="chip">{s.files.length} files</span>
              {s.evals && <span className="chip jade">evals</span>}
            </div>
          </Link>
        ))}
      </div>
    </Page>
  );
}

export function SkillPage() {
  const { name = "" } = useParams();
  const s = skillByName.get(name);
  if (!s)
    return (
      <Page title="No such skill">
        <p>
          There is no skill called <code>{name}</code>. <Link to="/skills">See every skill</Link>.
        </p>
      </Page>
    );
  const scripts = data.scripts.filter((x) => x.skill === s.name);
  return (
    <Page
      crumb={
        <>
          <Link to="/skills">Every skill</Link> / {CATEGORY_LABEL[s.category] ?? s.category}
        </>
      }
      title={<code className="h1code">{s.name}</code>}
      lede={s.what}
      toc={[
        { id: "front", label: "Frontmatter" },
        { id: "shape", label: "Shape" },
        ...(s.inputs.length ? [{ id: "inputs", label: "Inputs" }] : []),
        ...(s.steps.length ? [{ id: "steps", label: s.kind === "stack" ? "Rules" : "Steps" }] : []),
        ...(s.output ? [{ id: "output", label: "Output contract" }] : []),
        ...(s.gotchas.length ? [{ id: "gotchas", label: "Gotchas" }] : []),
        { id: "files", label: "Files" },
      ]}
      sources={[`plugins/${s.plugin}/skills/${s.name}/SKILL.md`, ...(s.evals ? [`evals/${s.name}/evals.json`] : [])]}
    >
      <div className="chips">
        <span className={`chip ${s.invocation === "command" ? "brass" : "sea"}`}>{s.invocation === "command" ? `typed only: /bearing:${s.name}` : `/bearing:${s.name}, or picked by the model`}</span>
        {s.kind === "stack" && <span className="chip">stack skill</span>}
        <span className="chip">{s.lines} lines</span>
        <span className="chip">{s.files.length} files</span>
        <span className={`chip ${s.evals ? "jade" : ""}`}>{s.evals ? "measured by evals" : "on evals/.pending"}</span>
      </div>
      {s.intro && (
        <p>
          <Rich text={s.intro} />
        </p>
      )}

      <H2 id="front">Frontmatter</H2>
      <Code>{[
        `name: ${s.name}`,
        `description: ${s.description}`,
        ...(s.invocation === "command" ? ["disable-model-invocation: true"] : []),
        ...(s.args ? [`argument-hint: "${s.args}"`] : []),
        `allowed-tools: ${s.tools.join(", ")}`,
        ...Object.entries(s.extra).map(([k, v]) => `${k}: ${v}`),
      ].join("\n")}</Code>
      {s.when && (
        <p>
          <strong>Triggers when</strong> {s.when}.
        </p>
      )}

      <H2 id="shape">Shape</H2>
      <SectionBar s={s} />

      {s.inputs.length > 0 && (
        <>
          <H2 id="inputs">Inputs</H2>
          <ul>
            {s.inputs.map((x, i) => (
              <li key={i}>
                <Rich text={x} />
              </li>
            ))}
          </ul>
        </>
      )}
      {s.layout && (
        <>
          <h3>Layout</h3>
          <p>
            <Rich text={s.layout} />
          </p>
        </>
      )}
      {s.steps.length > 0 && (
        <>
          <H2 id="steps">{s.kind === "stack" ? "Rules that matter most" : "Steps"}</H2>
          <ol className="steps">
            {s.steps.map((x, i) => (
              <li key={i}>
                <Rich text={x} />
              </li>
            ))}
          </ol>
        </>
      )}
      {s.commands.length > 0 && (
        <>
          <h3>Commands</h3>
          <ul>
            {s.commands.map((x, i) => (
              <li key={i}>
                <Rich text={x} />
              </li>
            ))}
          </ul>
        </>
      )}
      {s.output && (
        <>
          <H2 id="output">Output contract</H2>
          <p>
            <Rich text={s.output} />
          </p>
        </>
      )}
      {s.gotchas.length > 0 && (
        <>
          <H2 id="gotchas">Gotchas</H2>
          <ul>
            {s.gotchas.map((x, i) => (
              <li key={i}>
                <Rich text={x} />
              </li>
            ))}
          </ul>
        </>
      )}
      <H2 id="files">Files</H2>
      <div className="tree">
        {s.files.map((f) => (
          <div className="row" key={f.path}>
            <span>{f.path}</span>
            <span>{f.lines} lines</span>
          </div>
        ))}
      </div>
      {scripts.length > 0 && (
        <p>
          Scripts in this skill: {scripts.map((x, i) => (
            <span key={x.path}>
              {i ? ", " : ""}
              <code>{x.path}</code> ({x.lines} lines{x.header ? `: ${x.header.split("\n")[0]}` : ""})
            </span>
          ))}
        </p>
      )}
    </Page>
  );
}
