import { useState } from "react";
import { Terminal } from "../components/Terminal";
import { Code, H2, Note, Page, Rich, S } from "../components/ui";
import { data, skillByName } from "../lib/data";

const PROFILE: Record<string, string> = { ux: "ui", design_review: "ui" };

function Track() {
  const st = data.autopilot.stages;
  const [i, setI] = useState(0);
  const s = st[i];
  return (
    <figure className="track wide panel">
      <ol className="track-rail" aria-label="Autopilot stages">
        {st.map((x, n) => (
          <li key={x.name} className={`${n === i ? "now" : n < i ? "past" : ""} ${PROFILE[x.name] ? "cond" : ""}`}>
            <button type="button" onClick={() => setI(n)} aria-current={n === i ? "step" : undefined}>
              <span className="tk-dot" />
              <span className="tk-name">{x.name.replace("_", " ")}</span>
            </button>
          </li>
        ))}
      </ol>
      <div className="track-body" key={i}>
        <div>
          <h4>
            {i + 1}. {s.name}
            {PROFILE[s.name] && <span className="chip brass">only when profile {PROFILE[s.name]} = yes</span>}
          </h4>
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
        <button type="button" onClick={() => setI((x) => Math.max(0, x - 1))} disabled={i === 0}>
          Back
        </button>
        <button type="button" onClick={() => setI((x) => Math.min(st.length - 1, x + 1))} disabled={i === st.length - 1}>
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
      title="Autopilot and the task loop"
      lede={`Two ways to move a change from idea to merge request. By hand, a developer's day is four skills in a loop. Unattended, brg-autopilot walks ${st.length} stages and refuses to call a stage done until its gate holds on disk.`}
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
      <div className="loop wide">
        {[
          ["start-task", "Start", "A branch named feature/TASK-142-InvoiceTotals from the right base (develop, or main for a hotfix), a clean tree required, the handoff file, the progress record, the acceptance criteria restated."],
          ["workflow", "Where am I", "Reads the branch, changes, progress and gate state, places the work on the stage map, names the next skill. Never runs it."],
          ["session-handoff", "Pause", "Next, Done, Blockers, Open questions and Files touched written to the handoff file; the shared progress record updated. SessionStart prints it tomorrow."],
          ["merge-request", "Finish", "Branch name check, the gate, commit style audit, the template filled into .scratch/mr-<ID>.md, the push command printed, the ticket traced."],
        ].map(([s, t, d], i) => (
          <div key={s} className="loop-step">
            <span className="loop-n">{i + 1}</span>
            <b>{t}</b>
            <S name={s} />
            <p>{d}</p>
          </div>
        ))}
      </div>

      <H2 id="files">Two records of one task</H2>
      <div className="cols">
        <div className="card">
          <h4>
            <code>.bearing/state/&lt;branch&gt;.md</code>
          </h4>
          <p>Local and ignored. For the next session on this machine: what to do next, what is half done. The session hook prints its first 20 lines.</p>
        </div>
        <div className="card">
          <h4>
            <code>docs/progress/&lt;ID&gt;.md</code>
          </h4>
          <p>
            Committed, and in the MR. For teammates and fresh clones: status (started, in progress, blocked, in review), done, next, blockers. Written only
            through <code>plugins/bearing/skills/session-handoff/scripts/progress.py</code>, so its format holds.
          </p>
        </div>
      </div>

      <H2 id="split">Skill and script</H2>
      <p>
        Autopilot is split on purpose. The <S name="autopilot" /> skill drives: it runs each stage's skills and does the work. The{" "}
        <S name="brg-autopilot" /> script ({data.scripts.find((s) => s.name === "brg-autopilot")?.lines} lines of Python) keeps score: which stage is next,
        whether its gate holds, how many attempts are left, the digest of decisions, the report. The model never marks its own work done; it asks the script,
        and the script looks at the files.
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
      <p>Straight from the <code>STAGES</code> table in the script. Step through; each gate is a function that checks files, git and markers.</p>
      <Track />

      <H2 id="run">Watch a run start</H2>
      <p>The first gate refuses on an empty repository: there is no Makefile whose check records a pass.</p>
      <Terminal id="autopilot" height={360} />

      <H2 id="decisions">Decisions, Proposed</H2>
      <p>
        By hand, <S name="tech-decision" /> asks one question at a time, with options, a recommendation and the condition that would flip it, and records your
        answer as an Accepted ADR. Unattended, there is nobody to ask, so autopilot takes the recommendation and records it with{" "}
        <code>brg-autopilot decision</code> as <strong>Proposed</strong>. The decide gate fails if any ADR written this run says Accepted: only a person
        accepts. The report at <code>docs/autopilot/&lt;run&gt;.md</code> lists every Proposed decision for you to review in the MR.
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
          It never pushes, merges, tags or deploys. The mr gate requires that nothing was pushed. The run ends at a prepared merge request description and the
          push command, printed for you, and the same four walls that stop any agent stop this one.
        </p>
      </Note>
    </Page>
  );
}
