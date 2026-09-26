import { Cmd } from "@ui";
import { Link, useParams } from "react-router";
import { Page } from "../components/ui";
import { data, flowUses, rowsFor, skillByName } from "../lib/data";

export default function SkillPage() {
  const { name = "" } = useParams();
  const s = skillByName.get(name);
  if (!s)
    return (
      <Page title="No such skill" lede={`There is no Bearing skill called ${name}.`}>
        <Link to="/skills">Back to the catalogue</Link>
      </Page>
    );
  const plugin = s.plugin ?? "bearing";
  const rows = rowsFor(s.name);
  const uses = flowUses(s.name);
  const toc = [
    { id: "use", label: "When to use it" },
    ...(rows.length || uses.length ? [{ id: "where", label: "Where it fits" }] : []),
  ];
  return (
    <Page
      crumb={
        <>
          <Link to="/skills">Skills</Link> / {s.category}
        </>
      }
      title={<span className="sk-name">{s.name}</span>}
      lede={`${s.what}.`}
      toc={toc}
    >
      <div className="glance">
        <section>
          <h2 data-no-anchor>When to use it</h2>
          <p>Use it when {s.when}.</p>
        </section>
        <section>
          <h2 data-no-anchor>How to call it</h2>
          <Cmd>{`/${plugin}:${s.name}`}</Cmd>
          {s.args && (
            <small>
              Takes: <code>{s.args}</code>
            </small>
          )}
          <small>{s.invocation === "command" ? "Typed only." : "Or ask in your own words; it loads when the request matches."}</small>
        </section>
        <section>
          <h2 data-no-anchor>Plugin</h2>
          <p>
            <code>{plugin}</code>
          </p>
          <small>
            {plugin === "bearing" ? "Required; every install has it." : `Optional; install it with /plugin install ${plugin}@bearing.`}
          </small>
        </section>
        <section>
          <h2 data-no-anchor>Where it fits</h2>
          {rows.length || uses.length ? (
            <p>
              {rows.slice(0, 3).map((r, i) => (
                <span key={r.row.stage}>
                  {i > 0 && ", "}
                  <Link to={`/workflow/${data.stages.findIndex((x) => x.title === r.stage) + 1}`}>{r.stage}</Link>
                </span>
              ))}
              {rows.length > 0 && uses.length > 0 && "; "}
              {uses.length > 0 && `${uses.length} flow step${uses.length === 1 ? "" : "s"}`}
            </p>
          ) : (
            <p className="muted">Not named in a stage or flow.</p>
          )}
          <small>{s.category}</small>
        </section>
      </div>

      <h2 id="use">When to use it</h2>
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
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </Page>
  );
}
