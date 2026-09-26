import { Stepper, type Frame } from "../components/Stepper";
import { H2, Note, Page, Rich, S } from "../components/ui";
import { data } from "../lib/data";

const CONTRACT: Record<string, string> = {
  "reviewer": "Findings ranked Critical, High, Medium, Low, each with path:line, the claim, a concrete failure scenario and the fix; then the checklist items checked with none found, what was not reviewed, and what it noticed but could not verify. A finding without a failure scenario is dropped.",
  "verifier": "One verdict for one finding: CONFIRMED, REFUTED or UNCERTAIN, with the quoted lines that decide it and where the code is reachable from. It is given the location, the claim and the scenario, never the reviewer's reasoning.",
  "security-auditor": "Severity-ranked findings across authentication, resource-level authorisation (IDOR), injection, secrets, PII, output encoding, rate limiting, dependencies, infrastructure and mobile, each with reproduction steps; every checklist item reported as a finding or as checked, none found.",
  "explorer": "The answer in under 40 lines, the relevant paths with line numbers and a few words each, and what it could not confirm. It never pastes more than five lines of a file.",
  "test-writer": "Failing tests written in an isolated worktree, the failing output, and what production change the tests expect. It never edits production code and never invents a name it cannot find.",
  "doc-writer": "The document drafted from the kit's template and the code as it is, every claim sourced, anything unsourced marked unconfirmed; the files written; the questions for you. Edits under docs/ and README.md only.",
  "critic": "The three weakest claims in a PRD, HLD or LLD, the cheapest experiment that would falsify each, what the document does not say, and a verdict: accept, accept after the experiment, or do not accept until.",
};

const REVIEW: Frame[] = [
  {
    title: "Collect",
    where: "skills/branch-review, in the main session",
    body: (
      <p>
        The skill resolves the range (the argument, else <code>origin/develop...HEAD</code>, else main, else the last commit) and writes{" "}
        <code>diff.patch</code>, <code>stat.txt</code>, <code>files.txt</code> and <code>log.txt</code> under <code>.scratch/review/&lt;range-slug&gt;/</code>.
        The reviewers have no shell, so the session collects for them. <S name="brg-checklists" /> names the stack checklists that apply.
      </p>
    ),
  },
  {
    title: "Find",
    where: "gstack /review, or reviewer without gstack",
    body: (
      <p>
        The engine reads the diff with the universal checklist and each stack's review checklist and reports findings. gstack's review is the stronger finder
        (parallel specialists, an adversarial pass), so it is the engine whenever it is installed; <code>reviewer</code> is the fallback.
      </p>
    ),
  },
  {
    title: "Verify, blind",
    where: "one verifier per Critical and High, in parallel",
    body: (
      <p>
        Each serious finding goes to its own verifier with only its location, claim and failure scenario. The verifier tries to refute it by reading the code.
        It never sees why the finder believed it, so it cannot be talked into agreeing.
      </p>
    ),
  },
  {
    title: "Report",
    where: "the skill's output contract",
    body: (
      <p>
        Confirmed findings stay, refuted ones move to Dropped with the quoted lines that refute them, uncertain ones become Questions. The report ends with what
        was checked with none found and what was not reviewed, so silence is never mistaken for a pass.
      </p>
    ),
  },
];

function ReviewVisual(i: number) {
  const nodes = ["Session collects the diff", "Engine finds", "Verifiers, one per finding", "Report"];
  return (
    <div className="pipe">
      {nodes.map((n, k) => (
        <div key={n} className={`pipe-node ${k <= i ? "lit" : ""} ${k === i ? "now" : ""}`}>
          {k === 2 ? (
            <div className="fan">
              {["C1", "H1", "H2"].map((f, j) => (
                <span key={f} className={`fan-f ${k <= i ? (j === 1 ? "ref" : "conf") : ""}`}>
                  {f}
                  {k < i || k === i ? (j === 1 ? " refuted" : " confirmed") : ""}
                </span>
              ))}
            </div>
          ) : null}
          <b>{n}</b>
        </div>
      ))}
    </div>
  );
}

export function Agents() {
  return (
    <Page
      title="The seven agents"
      lede="A subagent is a fresh context with its own prompt, model and tool list. Bearing uses them for one reason: to get a second opinion that cannot be contaminated by the first, and cannot touch what it is judging."
      toc={[
        { id: "why", label: "Why subagents" },
        { id: "table", label: "The seven" },
        ...data.agents.map((a) => ({ id: a.name, label: a.name })),
        { id: "review", label: "The review pipeline" },
      ]}
      sources={data.agents.map((a) => `agents/${a.name}.md`)}
    >
      <H2 id="why">Why subagents</H2>
      <p>Three properties make a subagent worth its cost:</p>
      <ul>
        <li>
          <strong>Isolation.</strong> It starts without the session's reasoning, so a verifier checks the code and not the argument.
        </li>
        <li>
          <strong>Fewer tools.</strong> Five of the seven have Read, Grep and Glob only, and name Bash, Write and Edit in <code>disallowedTools</code> as
          well. A reviewer that cannot edit cannot "fix" what it is reviewing; one that cannot run a shell cannot be steered by a command in the diff.
        </li>
        <li>
          <strong>A return contract.</strong> Each agent's prompt ends with the exact shape of its report, so the calling skill can merge it without reading
          prose.
        </li>
      </ul>
      <Note title="Tools take bare names">
        <p>
          In an agent's <code>tools:</code> field, only bare tool names work (<code>Read, Grep, Glob</code>); a pattern like <code>Bash(git diff:*)</code> is
          not applied there. <code>lint-skills</code> fails an agent whose tools field contains a parenthesis.
        </p>
      </Note>

      <H2 id="table">The seven</H2>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>Agent</th>
              <th>Model</th>
              <th>Tools</th>
              <th>Turns</th>
              <th>Called from</th>
            </tr>
          </thead>
          <tbody>
            {data.agents.map((a) => (
              <tr key={a.name}>
                <td>
                  <a href={`#${a.name}`}>
                    <code>{a.name}</code>
                  </a>
                </td>
                <td>{a.model}</td>
                <td>
                  {a.tools.join(", ")}
                  {a.isolation ? ` (${a.isolation})` : ""}
                </td>
                <td>{a.maxTurns}</td>
                <td>{a.usedBy.length > 3 ? `${a.usedBy.length} skills` : a.usedBy.join(", ")}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {data.agents.map((a) => (
        <section key={a.name}>
          <H2 id={a.name}>
            <code className="h1code">{a.name}</code>
          </H2>
          <p className="agent-desc">{a.description}</p>
          <div className="chips">
            <span className="chip">{a.model}</span>
            {a.tools.map((t) => (
              <span key={t} className="chip jade">
                {t}
              </span>
            ))}
            {a.disallowed.map((t) => (
              <span key={t} className="chip signal">
                no {t}
              </span>
            ))}
            {a.isolation && <span className="chip brass">isolation: {a.isolation}</span>}
          </div>
          {a.intro && (
            <p>
              <Rich text={a.intro} />
            </p>
          )}
          <p>
            <strong>Returns.</strong> {CONTRACT[a.name]}
          </p>
          {a.usedBy.length > 0 && (
            <p>
              <strong>Called from</strong>{" "}
              {a.usedBy.map((s, i) => (
                <span key={s}>
                  {i ? ", " : ""}
                  <S name={s} />
                </span>
              ))}
              .
            </p>
          )}
        </section>
      ))}

      <H2 id="review">The review pipeline</H2>
      <p>
        <S name="branch-review" /> is where the agents work together. The design point is the blind verifier: two readers, one of whom never saw the other's
        reasoning.
      </p>
      <Stepper label="The review pipeline" frames={REVIEW} visual={ReviewVisual} interval={3600} />
      <p>
        <S name="vapt-report" /> follows the same shape with <code>security-auditor</code> as the finder (when neither claude-security nor gstack /cso is
        installed), and every Critical and High goes to a verifier the same way.
      </p>
    </Page>
  );
}
