import { useMemo, useState } from "react";
import { Link, useParams } from "react-router";
import { Code, H2, Page, S } from "../components/ui";
import { data, GROUP_LABEL, scriptByName, type Script } from "../lib/data";

/** The chapter that explains a script in depth, where there is one. */
const CHAPTER: Record<string, [string, string]> = {
  "brg-guard": ["/guard", "The guard"],
  "lib.sh": ["/session#adapters", "Anatomy of an adapter"],
  "session-start.sh": ["/session", "A session, event by event"],
  "inject-task-id.sh": ["/session", "A session, event by event"],
  "block-publish.sh": ["/session", "A session, event by event"],
  "format-file.sh": ["/session", "A session, event by event"],
  "precompact.sh": ["/session", "A session, event by event"],
  "stop-summary.sh": ["/session", "A session, event by event"],
  "brg-scaffold": ["/scaffold", "Scaffolding a repository"],
  "brg-adopt": ["/adopt", "Adopting a repository"],
  "brg-autopilot": ["/autopilot", "Autopilot and the task loop"],
  "brg-tracker": ["/trackers", "Trackers"],
  "brg-jira": ["/trackers", "Trackers"],
  "brg-gitlab": ["/trackers", "Trackers"],
  "brg-github": ["/trackers", "Trackers"],
  "brg-rest": ["/trackers", "Trackers"],
  "brg-harness": ["/harnesses", "Other harnesses"],
  "install.sh": ["/install", "Install, doctor, packs"],
  "brg-doctor": ["/install#doctor", "Install, doctor, packs"],
  "brg-install-packs": ["/install#packs", "Install, doctor, packs"],
  "harness-eval.py": ["/gates#harness", "Gates, tests and CI"],
  "lint-skill-tools.py": ["/skills-work#tools", "How skills work"],
  "lint-skill-evals.py": ["/skills-work#evals", "How skills work"],
  "skill-evals.py": ["/skills-work#evals", "How skills work"],
  "gen-guide.py": ["/skills-work#packs", "How skills work"],
  "gen-devguide.py": ["/change#recipes", "Changing Bearing"],
};

function callers(s: Script) {
  const bySkill = data.skills.filter((k) => k.tools.some((t) => t.includes(s.name))).map((k) => k.name);
  const byScript = data.scripts.filter((x) => x.path !== s.path && x.calls.includes(s.name)).map((x) => x.name);
  const byHook = data.hooks.filter((h) => h.script === s.name || (s.name === "brg-guard" && h.script)).map((h) => h.event);
  return { bySkill, byScript, byHook };
}

export function Scripts() {
  const [q, setQ] = useState("");
  const [skillScripts, setSkillScripts] = useState(false);
  const groups = useMemo(() => {
    const m = new Map<string, Script[]>();
    for (const s of data.scripts) {
      if (s.group === "skill" && !skillScripts) continue;
      if (q && !`${s.path} ${s.header} ${s.functions.join(" ")} ${s.env.join(" ")}`.toLowerCase().includes(q.toLowerCase())) continue;
      if (!m.has(s.group)) m.set(s.group, []);
      m.get(s.group)!.push(s);
    }
    const order = ["guard", "hooks", "scaffold", "install", "tracker", "workflow", "generators", "quality", "skill"];
    return order.filter((g) => m.has(g)).map((g) => [g, m.get(g)!] as const);
  }, [q, skillScripts]);
  const maxLines = Math.max(...data.scripts.map((s) => s.lines));
  return (
    <Page
      full
      title="Every script"
      lede={`${data.counts.scripts} scripts, ${data.counts.scriptLines.toLocaleString("en")} lines. Each entry is read from the script itself: its header comment, the functions it defines, the environment it reads and the kit scripts it calls.`}
    >
      <div className="filters">
        <input type="search" placeholder="Filter: tracker, BEARING_ENV, precompact" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Filter scripts" />
        <button type="button" aria-pressed={skillScripts} onClick={() => setSkillScripts((x) => !x)}>
          Include scripts inside skills
        </button>
      </div>
      {groups.map(([g, list]) => (
        <section key={g}>
          <h2 className="grouphead">{GROUP_LABEL[g] ?? g}</h2>
          <div className="scriptlist">
            {list.map((s) => (
              <Link key={s.path} to={s.group === "skill" ? `/skills/${s.skill}` : `/scripts/${s.name}`} className="scriptrow">
                <code>{s.path}</code>
                <span className="sr-desc">{s.header.split("\n").find((l) => l.trim()) ?? ""}</span>
                <span className="sr-len" aria-label={`${s.lines} lines`}>
                  <span style={{ width: `${Math.max(2, (s.lines / maxLines) * 100)}%` }} />
                  <small>{s.lines}</small>
                </span>
              </Link>
            ))}
          </div>
        </section>
      ))}
    </Page>
  );
}

export function ScriptPage() {
  const { name = "" } = useParams();
  const s = scriptByName.get(name);
  if (!s)
    return (
      <Page title="No such script">
        <p>
          There is no script called <code>{name}</code>. <Link to="/scripts">See every script</Link>.
        </p>
      </Page>
    );
  const c = callers(s);
  const ch = CHAPTER[s.name];
  return (
    <Page
      crumb={
        <>
          <Link to="/scripts">Every script</Link> / {GROUP_LABEL[s.group] ?? s.group}
        </>
      }
      title={<code className="h1code">{s.path}</code>}
      lede={s.header.split("\n").find((l) => l.trim())?.replace(/^[a-z0-9._-]+: /i, "")}
      toc={[
        { id: "header", label: "What it says it does" },
        { id: "wiring", label: "Wiring" },
        ...(s.functions.length ? [{ id: "functions", label: "Functions" }] : []),
      ]}
      sources={[s.path]}
    >
      <div className="chips">
        <span className="chip">{s.lang}</span>
        <span className="chip">{s.lines} lines</span>
        {s.functions.length > 0 && <span className="chip">{s.functions.length} functions</span>}
        {ch && (
          <Link to={ch[0]} className="chip sea">
            explained in: {ch[1]}
          </Link>
        )}
      </div>
      <H2 id="header">What it says it does</H2>
      <p>The script's own header, as its author wrote it. It is also what the script prints for --help in most cases.</p>
      <Code>{s.header || "(no header comment)"}</Code>

      <H2 id="wiring">Wiring</H2>
      <div className="tablewrap">
        <table>
          <tbody>
            <tr>
              <th>Reads</th>
              <td>{s.env.length ? s.env.map((e) => <code key={e}>{e} </code>) : "no BEARING_ or CLAUDE_ variables"}</td>
            </tr>
            <tr>
              <th>Calls</th>
              <td>
                {s.calls.length
                  ? s.calls.map((x, i) => (
                      <span key={x}>
                        {i ? ", " : ""}
                        <S name={x} />
                      </span>
                    ))
                  : "no other kit script"}
              </td>
            </tr>
            <tr>
              <th>Called by hooks</th>
              <td>{c.byHook.length ? c.byHook.join(", ") : "none"}</td>
            </tr>
            <tr>
              <th>Called by scripts</th>
              <td>
                {c.byScript.length
                  ? c.byScript.map((x, i) => (
                      <span key={x}>
                        {i ? ", " : ""}
                        <S name={x} />
                      </span>
                    ))
                  : "none"}
              </td>
            </tr>
            <tr>
              <th>Granted to skills</th>
              <td>
                {c.bySkill.length
                  ? c.bySkill.map((x, i) => (
                      <span key={x}>
                        {i ? ", " : ""}
                        <S name={x} />
                      </span>
                    ))
                  : "none"}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      {s.functions.length > 0 && (
        <>
          <H2 id="functions">Functions</H2>
          <p>In the order they are defined. Reading them top to bottom is a fair outline of the script.</p>
          <div className="fnlist">
            {s.functions.map((f, i) => (
              <code key={`${f}-${i}`}>{f}</code>
            ))}
          </div>
        </>
      )}
    </Page>
  );
}
