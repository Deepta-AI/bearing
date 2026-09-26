import { Link, useParams } from "react-router";
import { PackTag, SkillLink } from "../components/ui";
import { data, packKey } from "../lib/data";

export default function Workflow() {
  const { stage } = useParams();
  const idx = Math.min(Math.max(Number(stage ?? 1) - 1, 0), data.stages.length - 1) || 0;
  const st = data.stages[idx];
  return (
    <div className="page full">
      <article>
        <h1>Every stage, one skill</h1>
        <p className="lede">
          Twelve stages from an idea to a service in production. Each row is one moment in the work and names the single strongest skill for it;
          the alternates say when something else fits better.
        </p>
        <div className="wf">
          <ol className="line" aria-label="Stages">
            {data.stages.map((s, i) => (
              <li key={s.title}>
                <Link to={`/workflow/${i + 1}`} className={i === idx ? "on" : i < idx ? "past" : ""} aria-current={i === idx ? "step" : undefined}>
                  <span className="dot" aria-hidden="true" />
                  <span>{s.title}</span>
                  <span className="ct">{s.rows.length}</span>
                </Link>
              </li>
            ))}
          </ol>
          <div>
            <div style={{ marginBottom: "var(--s4)" }}>
              <h2 style={{ margin: 0 }}>{st.title}</h2>
              <p className="muted" style={{ margin: "var(--s2) 0 0" }}>
                For {st.when}.
              </p>
            </div>
            <div className="rows">
              {st.rows.map((r) => {
                const k = packKey(r.from === "bearing" ? "bearing" : r.from);
                return (
                  <div className="row" key={r.stage} style={{ ["--c" as string]: `var(--${k === "bearing" ? "jade" : k})` }}>
                    <div className="when">{r.stage}</div>
                    <div className="use">
                      <SkillLink name={r.skill} />
                      <PackTag pack={r.from} />
                    </div>
                    <p className="out">{r.output}</p>
                    {r.alternate && r.alternate !== "none" && <p className="alt">Instead: {r.alternate}</p>}
                  </div>
                );
              })}
            </div>
            <div style={{ display: "flex", justifyContent: "space-between", marginTop: "var(--s5)", gap: "var(--s3)" }}>
              {idx > 0 ? (
                <Link className="btn" to={`/workflow/${idx}`}>
                  {data.stages[idx - 1].title}
                </Link>
              ) : (
                <span />
              )}
              {idx < data.stages.length - 1 && (
                <Link className="btn" to={`/workflow/${idx + 2}`}>
                  {data.stages[idx + 1].title}
                </Link>
              )}
            </div>
            <h2 style={{ fontSize: "1.2rem", marginTop: "var(--s7)" }}>How to read this map</h2>
            <ul>
              {data.notes.map((n) => (
                <li key={n} className="muted">
                  {n}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </article>
    </div>
  );
}
