import { Code, Page } from "../components/ui";
import { data } from "../lib/data";

const pct = (x: number | null | undefined) => (x == null ? "not measured" : `${Math.round(x * 100)}%`);
const ARM_LABEL: Record<string, string> = { with_skill: "With the skill", with_the_alternative: "With the alternative", without_skill: "Without" };
const ARM_ORDER = ["with_skill", "with_the_alternative", "without_skill"];

export function Evals() {
  const e = data.evals;
  const runs = [...e.runs].reverse();
  const latest = runs[0];
  const measured = Object.entries(e.skillsMeasured);
  const triggered = Object.entries(e.triggerMeasured);
  return (
    <Page
      crumb="Reference"
      title="Evals and results"
      lede="What is defined, what was measured, and nothing else. Every number here comes from evals/scoreboard.jsonl, written by make evals-weekly; a skill not yet measured says so."
      toc={[
        { id: "defined", label: "What is defined" },
        { id: "latest", label: "Latest run" },
        { id: "skills", label: "With and without the skill" },
        { id: "triggers", label: "Does the request load the skill" },
        { id: "run", label: "Run them yourself" },
      ]}
    >
      <h2 id="defined">What is defined</h2>
      <div className="list">
        <div>
          <b>Skill evals</b>
          {e.skillsWithEvals} skills, {e.evalCases} cases. Each case runs the task with the skill and without it, in a fresh session, and a grader
          checks the same expectations against both.
        </div>
        <div>
          <b>Trigger evals</b>
          {e.triggerRequests} plain requests over {e.triggerSkills} skills: three per skill that should load it, two near misses that should load a
          sibling instead.
        </div>
        <div>
          <b>Harness evals</b>
          Real Claude Code sessions against the hooks: push, deploy, edit lint, the Stop gate green and red, compaction.
        </div>
      </div>

      <h2 id="latest">Latest run</h2>
      {latest ? (
        <div className="tbl-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Date</th>
                <th>Commit</th>
                <th>Trigger requests</th>
                <th>Recall</th>
                <th>False triggers</th>
                <th>Harness</th>
                <th>Skills with and without</th>
              </tr>
            </thead>
            <tbody>
              {runs.map((r) => (
                <tr key={r.date + r.commit}>
                  <td>
                    <b style={{ color: "var(--ink)" }}>{r.date}</b>
                    {r.limited ? " (stopped at the usage limit)" : ""}
                  </td>
                  <td>
                    <code>{r.commit || "unknown"}</code>
                  </td>
                  <td>{r.triggerCases}</td>
                  <td>{pct(r.recall)}</td>
                  <td>{pct(r.falseRate)}</td>
                  <td>
                    {r.harnessPassed} of {r.harnessRuns}
                  </td>
                  <td>{r.skillsMeasured}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <p className="muted">Not measured yet: no run of make evals-weekly has been recorded. The first run fills this table.</p>
      )}

      <h2 id="skills">With and without the skill</h2>
      {measured.length ? (
        <div className="tbl-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Skill</th>
                <th>Measured</th>
                {ARM_ORDER.map((a) => (
                  <th key={a}>{ARM_LABEL[a]}</th>
                ))}
                <th>Result</th>
              </tr>
            </thead>
            <tbody>
              {measured.map(([name, m]) => (
                <tr key={name}>
                  <td>
                    <b style={{ color: "var(--ink)" }}>{name}</b>
                  </td>
                  <td>{m.date}</td>
                  {ARM_ORDER.map((a) => (
                    <td key={a}>{a in m.arms ? pct(m.arms[a]) : "n/a"}</td>
                  ))}
                  <td>{m.result}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <p className="muted">
          Not measured yet: 0 of {e.skillsWithEvals} skills have a recorded with and without run. The weekly run measures five skills at a time.
        </p>
      )}

      <h2 id="triggers">Does the request load the skill</h2>
      {triggered.length ? (
        <div className="tbl-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Skill</th>
                <th>Measured</th>
                <th>Loaded when it should</th>
                <th>Loaded on a near miss</th>
              </tr>
            </thead>
            <tbody>
              {triggered.map(([name, t]) => (
                <tr key={name}>
                  <td>
                    <b style={{ color: "var(--ink)" }}>{name}</b>
                  </td>
                  <td>{t.date}</td>
                  <td>
                    {t.loaded} of {t.should}
                  </td>
                  <td>
                    {t.false} of {t.near}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <p className="muted">Not measured yet: 0 of {e.triggerSkills} skills have a recorded trigger run.</p>
      )}

      <h2 id="run">Run them yourself</h2>
      <p>The evals run real Claude Code sessions on your own subscription and stop cleanly at the usage limit. From a Bearing checkout:</p>
      <Code>{`make evals-weekly     # harness, five skill evals, a rotation of trigger requests; one scoreboard row
make evals-timer      # prints the systemd units that run it every Sunday`}</Code>
    </Page>
  );
}
