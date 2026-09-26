import { Link, useParams } from "react-router";
import { Code, Page, PackTag, SkillLink } from "../components/ui";
import { data, flowUses, invokeName, rowsFor, skillByName, verdictLabel, type Measured } from "../lib/data";

const verdictColour: Record<string, string> = {
  "bearing-stronger": "var(--jade)",
  "alternative-stronger": "var(--warn)",
  "different-job": "var(--gsd)",
  "no-alternative": "var(--muted)",
  unverified: "var(--muted)",
};

export default function SkillPage() {
  const { name = "" } = useParams();
  const s = skillByName.get(name);
  if (!s)
    return (
      <Page title="No such skill" lede={`There is no Bearing skill called ${name}.`}>
        <Link to="/skills">Back to the catalogue</Link>
      </Page>
    );
  const c = data.comparisons[s.name];
  const rows = rowsFor(s.name);
  const uses = flowUses(s.name);
  const toc = [
    { id: "use", label: "When to use it" },
    ...(c ? [{ id: "compare", label: "Compared with the alternative" }] : []),
    ...(rows.length || uses.length ? [{ id: "where", label: "Where it fits" }] : []),
  ];
  return (
    <Page
      crumb={
        <>
          <Link to="/skills">Skills</Link> / {s.category}
        </>
      }
      title={<span className="sk-head">{s.name}</span>}
      toc={toc}
    >
      <div className="sk-head">
        <div className="meta">
          <span className="tag">{s.invocation === "command" ? "You type it" : "Loads on its own when the request matches"}</span>
          <span className="tag">{s.category}</span>
        </div>
      </div>
      <p className="lede" style={{ marginTop: 0 }}>
        {s.what}.
      </p>

      <h2 id="use">When to use it</h2>
      <p>Use it when {s.when}.</p>
      {s.phrases.length > 0 && (
        <>
          <p className="muted" style={{ marginBottom: 0 }}>
            Phrases that {s.invocation === "auto" ? "trigger it" : "describe it"}:
          </p>
          <div className="phr">
            {s.phrases.map((p) => (
              <span key={p}>"{p}"</span>
            ))}
          </div>
        </>
      )}
      <Code>{`${s.name}${s.args ? " " + s.args : ""}`}</Code>

      {c && (
        <>
          <h2 id="compare">Compared with the alternative</h2>
          <div className="verdict" style={{ ["--c" as string]: verdictColour[c.verdict] }}>
            <div>
              <b>{verdictLabel[c.verdict]}</b>
              <p>{c.why}</p>
            </div>
          </div>
          {c.best_alternative && (
            <div className="versus">
              <div>
                <h3>Use {s.name} when</h3>
                <div className="who">{s.name}</div>
                <p>{c.use_bearing_when || "It is the recommended choice for this step."}</p>
              </div>
              <div>
                <h3>Use the alternative when</h3>
                <div className="who">
                  <SkillLink name={c.best_alternative.invoke ?? invokeName(c.best_alternative.name, c.best_alternative.pack)} /> <PackTag pack={c.best_alternative.pack} />
                </div>
                {c.best_alternative.invoke && c.best_alternative.invoke !== c.best_alternative.name && <p className="muted">{c.best_alternative.name}</p>}
                <p>{c.use_alternative_when || "Rarely; it does not cover this step as fully."}</p>
                {!c.best_alternative.installed && <p className="muted">Not installed by the kit's profiles.</p>}
              </div>
            </div>
          )}
          {c.recommendation === "feed-rules" && (
            <div className="note">
              The alternative has rules worth taking. The kit keeps {s.name} and folds in what the alternative does better; the comparison above
              names it.
            </div>
          )}
          {c.measured ? (
            <MeasuredBlock m={c.measured} skill={s.name} alt={c.best_alternative?.invoke ?? c.best_alternative?.name} />
          ) : (
            <p className="muted" style={{ fontSize: ".86rem" }}>
              Judged by reading both skills in full against the rule that the strongest skill wins; not yet measured. Confidence: {c.confidence}.
            </p>
          )}
        </>
      )}

      {(rows.length > 0 || uses.length > 0) && (
        <>
          <h2 id="where">Where it fits</h2>
          {rows.length > 0 && (
            <ul>
              {rows.map((r) => (
                <li key={r.row.stage}>
                  <Link to={`/workflow/${data.stages.findIndex((x) => x.title === r.stage) + 1}`}>{r.stage}</Link>: {r.row.stage}. {r.row.output}.
                </li>
              ))}
            </ul>
          )}
          {uses.length > 0 && (
            <ul>
              {uses.map((u) => (
                <li key={`${u.flow.id}-${u.step.id}`}>
                  <Link to={`/flows/${u.flow.id}?step=${u.step.id}`}>
                    {u.flow.title}: {u.step.title}
                  </Link>
                  {u.asAlternate ? ` (as the alternate to ${u.step.skill})` : ""}
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </Page>
  );
}

const armLabel = (arm: string, skill: string, alt?: string) =>
  arm === "with_skill" ? skill : arm === "with_the_alternative" ? alt ?? "the alternative" : "no skill";

function MeasuredBlock({ m, skill, alt }: { m: Measured; skill: string; alt?: string }) {
  const arms = (["with_skill", "with_the_alternative", "without_skill"] as const).filter((a) => m.arms[a]);
  return (
    <div className="measured">
      <h3>Measured</h3>
      <p>
        {m.result === "bearing ahead"
          ? `${skill} passed more of the expectations than any rival.`
          : m.result === "rival ahead"
            ? `${armLabel(m.closest, skill, alt)} passed more of the expectations than ${skill}.`
            : `${skill} and ${armLabel(m.closest, skill, alt)} were within 10 points of each other.`}
      </p>
      <table>
        <thead>
          <tr>
            <th>Run with</th>
            <th>Expectations passed</th>
            <th>Tokens</th>
            <th>Seconds</th>
          </tr>
        </thead>
        <tbody>
          {arms.map((a) => {
            const r = m.arms[a]!;
            return (
              <tr key={a}>
                <td>{armLabel(a, skill, alt)}</td>
                <td>
                  <span className="bar" style={{ ["--w" as string]: `${Math.round(r.pass_rate * 100)}%` }} />
                  {Math.round(r.pass_rate * 100)}%
                </td>
                <td>{r.tokens.toLocaleString("en")}</td>
                <td>{r.seconds}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
      <p className="muted" style={{ fontSize: ".86rem" }}>
        {m.cases} cases, {m.runs_per_arm} run per arm, graded blind against written expectations; {m.model}, {m.date}. Few cases: read the margin
        as a direction, not a size.
      </p>
    </div>
  );
}
