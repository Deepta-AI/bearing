import { Link, Navigate, useParams, useSearchParams } from "react-router";
import FlowDiagram from "../components/FlowDiagram";
import { data } from "../lib/data";

export default function FlowPage() {
  const { id } = useParams();
  const [params] = useSearchParams();
  const flow = data.flows.find((f) => f.id === id);
  if (!flow) return <Navigate to="/flows/greenfield" replace />;
  return (
    <div className="page full">
      <article>
        <div className="crumb">Flows</div>
        <nav className="flow-tabs" aria-label="Flows">
          {data.flows.map((f) => (
            <Link key={f.id} to={`/flows/${f.id}`} className={f.id === flow.id ? "on" : ""}>
              {f.title}
            </Link>
          ))}
        </nav>
        <div className="flow-head">
          <div>
            <h1>{flow.title}</h1>
            <p className="lede" style={{ marginBottom: 0 }}>
              {flow.tagline} {flow.when}
            </p>
          </div>
        </div>
        <p className="muted">
          Open any step to see what the skill does, why it is the strongest choice there, what you get and when to use something else. Answer the
          questions on the line to see the steps that apply to your change.
        </p>
        <FlowDiagram key={flow.id} flow={flow} initialStep={params.get("step") ?? undefined} />
      </article>
    </div>
  );
}
