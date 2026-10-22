import { useEffect, useRef, useState, type CSSProperties, type KeyboardEvent } from "react";
import { Terminal } from "../components/Terminal";
import { Code, H2, Note, Page, Rich, S } from "../components/ui";
import { data, skillByName } from "../lib/data";

const PROFILE: Record<string, string> = { ux: "ui", design_review: "ui" };

function Track() {
  const st = data.autopilot.stages;
  const [i, setI] = useState(0);
  const btns = useRef<(HTMLButtonElement | null)[]>([]);
  const moved = useRef(false);
  const s = st[i];
  // Keep the chosen stage in view when the rail scrolls on a narrow screen.
  useEffect(() => {
    if (!moved.current) return;
    btns.current[i]?.scrollIntoView({ block: "nearest", inline: "nearest" });
  }, [i]);
  const go = (n: number) => {
    moved.current = true;
    setI(Math.max(0, Math.min(st.length - 1, n)));
  };
  const onKey = (e: KeyboardEvent<HTMLButtonElement>) => {
    const to = e.key === "ArrowRight" ? i + 1 : e.key === "ArrowLeft" ? i - 1 : e.key === "Home" ? 0 : e.key === "End" ? st.length - 1 : null;
    if (to === null) return;
    e.preventDefault();
    go(to);
    btns.current[Math.max(0, Math.min(st.length - 1, to))]?.focus();
  };
  const rail = { "--n": st.length, "--done": st.length > 1 ? i / (st.length - 1) : 0 } as CSSProperties;
  return (
    <figure className="track wide panel">
      <div className="track-scroll">
        <ol className="track-rail" aria-label="Autopilot stages" style={rail}>
          {st.map((x, n) => (
            <li key={x.name} className={`${n === i ? "now" : n < i ? "past" : ""} ${PROFILE[x.name] ? "cond" : ""}`}>
              <button
                type="button"
                ref={(el) => {
                  btns.current[n] = el;
                }}
                onClick={() => go(n)}
                onKeyDown={onKey}
                aria-current={n === i ? "step" : undefined}
                aria-label={`Stage ${n + 1} of ${st.length}: ${x.name.replace("_", " ")}`}
              >
                <span className="tk-dot" />
                <span className="tk-name" aria-hidden="true">
                  {x.name.replace("_", " ")}
                </span>
              </button>
            </li>
          ))}
        </ol>
      </div>
      <div className="track-body" key={i}>
        <div>
          <h3 data-no-anchor>
            <span className="eyebrow" style={{ margin: 0 }}>
              {i + 1} of {st.length}
            </span>
            {s.name.replace("_", " ")}
            {PROFILE[s.name] && <span className="chip brass">only when profile {PROFILE[s.name]} = yes</span>}
          </h3>
          <p className="tk-label">Skill</p>
          <p>
            <Rich text={s.skill.replace(/(?<![\w`-])[a-z0-9]+(?:-[a-z0-9]+)*(?![\w`-])/g, (w) => (skillByName.has(w) ? `\`${w}\`` : w))} />
          </p>
        </div>
        <div className="tk-gate">
          <p className="tk-label">Gate, checked on disk by brg-autopilot done {s.name}</p>
          <p>{s.gate}</p>
        </div>
      </div>
      <div className="an-ctl">
        <button type="button" onClick={() => go(i - 1)} disabled={i === 0}>
          Back
        </button>
        <button type="button" onClick={() => go(i + 1)} disabled={i === st.length - 1}>
          Next stage
        </button>
      </div>
    </figure>
  );
}

export function Autopilot() {
  const st = data.autopilot.stages;
  return (
    <Page
      crumb="Chapter 9 / Workflow"
      title="Autopilot and the task loop"
      lede={`Two ways from idea to merge request. By hand, a developer's day is four skills in a loop. Unattended, brg-autopilot walks ${st.length} stages and marks a stage done only when its gate holds on disk.`}
      toc={[
        { id: "loop", label: "The task loop by hand" },
        { id: "files", label: "Two records of one task" },
        { id: "split", label: "Skill and script" },
        { id: "stages", label: `The ${st.length} stages` },
        { id: "run", label: "Watch a run start" },
        { id: "decisions", label: "Decisions, Proposed" },
        { id: "limits", label: "Attempts, blocks, resume" },
        { id: "refuses", label: "What it never does" },
      ]}
      sources={["plugins/bearing/bin/brg-autopilot", "plugins/bearing/skills/autopilot/SKILL.md", "plugins/bearing/skills/start-task/SKILL.md", "plugins/bearing/skills/session-handoff/SKILL.md", "plugins/bearing/skills/merge-request/SKILL.md"]}
    >
      <H2 id="loop">The task loop by hand</H2>
      <ol className="stepcs">
        {[
          ["start-task", "Start", "Needs a clean tree. Creates feature/TASK-142-InvoiceTotals from the right base (develop, or main for a hotfix), the handoff file and the progress record, and restates the acceptance criteria."],
          ["workflow", "Where am I", "Reads the branch, changes, progress and gate state. Places the work on the stage map and names the next skill, without running it."],
          ["session-handoff", "Pause", "Writes Next, Done, Blockers, Open questions and Files touched to the handoff file, and updates the shared progress record. SessionStart prints it tomorrow."],
          ["merge-request", "Finish", "Checks the branch name, runs the gate, audits commit style, fills .scratch/mr-<ID>.md, prints the push command and traces the ticket."],
        ].map(([s, t, d], i, all) => (
          <li key={s}>
            <div className="stepc">
              <div className="of">
                {i + 1} of {all.length}
              </div>
              <h3>{t}</h3>
              <p>
                <S name={s} />
              </p>
              <p>{d}</p>
            </div>
          </li>
        ))}
      </ol>

      <H2 id="files">Two records of one task</H2>
      <div className="cols">
        <div className="card">
          <h3>
            <code>.bearing/state/&lt;branch&gt;.md</code>
          </h3>
          <p>Local and ignored. For the next session on this machine: what is next and what is half done. The session hook prints its first 8 lines.</p>
        </div>
        <div className="card">
          <h3>
            <code>docs/progress/&lt;ID&gt;.md</code>
          </h3>
          <p>
            Committed, and in the MR. For teammates and fresh clones: status (started, in progress, blocked, in review), done, next, blockers. Only{" "}
            <code>plugins/bearing/skills/session-handoff/scripts/progress.py</code> writes it, so its format holds.
          </p>
        </div>
      </div>

      <H2 id="split">Skill and script</H2>
      <p>
        The <S name="autopilot" /> skill drives: it runs each stage's skills and does the work. The <S name="brg-autopilot" /> script (
        {data.scripts.find((s) => s.name === "brg-autopilot")?.lines} lines of Python) keeps score: the next stage, whether its gate holds, attempts left,
        the decision digest, the report. The model never marks its own work done. It asks the script, and the script reads the files.
      </p>
      <Code cap="the script's commands">{`brg-autopilot start "<statement>"      begin a run (refuses when one is open)
brg-autopilot next                     the next stage, its skill and its gate
brg-autopilot done <stage>             check the gate; mark done or say what is missing
brg-autopilot fail <stage> "<why>"     count a failed attempt (${data.autopilot.maxAttempts} and the stage is blocked)
brg-autopilot decision <key> <choice> <alternatives> <why> [--adr PATH]
brg-autopilot profile --ui|--data|--api|--deploy yes|no --why W
brg-autopilot status | report | stages
brg-autopilot launch "<statement>"     run it headless: claude -p with autopilot`}</Code>

      <H2 id="stages">The {st.length} stages</H2>
      <p>From the <code>STAGES</code> table in the script. Each gate is a function that checks files, git and markers. Use the arrow keys to step.</p>
      <Track />

      <H2 id="run">Watch a run start</H2>
      <p>The first gate refuses on an empty repository: there is no Makefile whose check records a pass.</p>
      <Terminal id="autopilot" height={360} />

      <H2 id="decisions">Decisions, Proposed</H2>
      <p>
        By hand, <S name="tech-decision" /> asks one question at a time, with options, a recommendation and the condition that would flip it. Your answer
        becomes an Accepted ADR. Unattended, nobody is there to ask. Autopilot takes the recommendation and records it with{" "}
        <code>brg-autopilot decision</code> as <strong>Proposed</strong>. The decide gate fails if any ADR written this run says Accepted: only a person
        accepts. The report at <code>docs/autopilot/&lt;run&gt;.md</code> lists every Proposed decision for review in the MR.
      </p>
      <p>
        The product profile (ui, data, api, deploy, llm) decides which stages apply, and the dod gate refuses a profile that contradicts the repository, such as{" "}
        <code>ui=no</code> with React in package.json.
      </p>

      <H2 id="limits">Attempts, blocks, resume</H2>
      <ul>
        <li>
          A gate that fails prints what is missing. The skill fixes it and calls <code>done</code> again, or records <code>fail</code> with a reason.
        </li>
        <li>
          {data.autopilot.maxAttempts} failed attempts block the stage. <code>next</code> then says to write the report and stop; the report lists the
          blockers.
        </li>
        <li>
          State lives in <code>.bearing/state/autopilot.json</code>, so a run survives compaction (the snapshot hook helps) and a new session resumes with the skill's{" "}
          <code>--resume</code>, which runs <code>status</code> then <code>next</code>. The script's own <code>start</code> refuses while a run is open, naming the
          stage it stopped at.
        </li>
        <li>
          The dod gate wants evidence that the thing runs: when the repository ships something runnable, a <code>.scratch/smoke-*.md</code> newer than the last
          commit saying <code>smoke: N requests checked, 0 failed</code> with N above zero.
        </li>
      </ul>

      <H2 id="refuses">What it never does</H2>
      <Note tone="signal">
        <p>
          It never runs git push, merges, tags or deploys. Where you opted the repository in (<code>BEARING_AUTO_PUSH</code>), its last stage requests a push
          of the task branch. The Stop hook makes that push from a fresh clone after the gate, and the mr gate fails on any other push. The run ends at a
          prepared merge request description and the push command, printed for you. The four walls that stop any agent stop this one too.
        </p>
      </Note>
    </Page>
  );
}
