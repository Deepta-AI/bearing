import { DocPage } from "@ui";
import { Link, useParams } from "react-router";
import { PackTag, SkillLink } from "../components/ui";
import { data, packKey } from "../lib/data";

export default function Workflow() {
  const { stage } = useParams();
  const idx = Math.min(Math.max(Number(stage ?? 1) - 1, 0), data.stages.length - 1) || 0;
  const st = data.stages[idx];
  return (
    <DocPage
      full
      crumb={
        <>
          Workflow stage {idx + 1} of {data.stages.length}
        </>
      }
      title={st.title}
      lede={<>For {st.when}.</>}
      pager={{ prev: "Previous stage", next: idx === data.stages.length - 1 ? "Next" : "Next stage" }}
    >
      <ol className="stage-rail" aria-label="Stages">
        {data.stages.map((s, i) => (
          <li key={s.title}>
            <Link to={`/workflow/${i + 1}`} className={i === idx ? "on" : i < idx ? "past" : ""} aria-current={i === idx ? "step" : undefined} title={s.title}>
              <b>{i + 1}</b>
              <span>{s.title}</span>
            </Link>
          </li>
        ))}
      </ol>
      <div className="rows">
        {st.rows.map((r) => {
          const k = packKey(r.from === "bearing" ? "bearing" : r.from);
          return (
            <div className="row" key={r.stage} style={{ ["--c" as string]: `var(--${k === "bearing" ? "accent" : k})` }}>
              <div className="when">{r.stage}</div>
              <div className="use">
                <SkillLink name={r.skill} />
                <PackTag pack={r.from} />
              </div>
              <p className="out">{r.output}</p>
            </div>
          );
        })}
      </div>
      <section className="stage-notes">
        <h2 id="read">How to read this map</h2>
        <p className="muted">
          Twelve stages from an idea to a service in production. Each row is one moment in the work and names the one skill the workflow runs for
          it.
        </p>
        <ul>
          {data.notes.map((n) => (
            <li key={n} className="muted">
              {n}
            </li>
          ))}
        </ul>
      </section>
    </DocPage>
  );
}
