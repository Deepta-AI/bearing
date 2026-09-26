import { DocPage } from "@ui";
import { Link, Navigate, useParams, useSearchParams } from "react-router";
import FlowDiagram from "../components/FlowDiagram";
import { data } from "../lib/data";

export default function FlowPage() {
  const { id } = useParams();
  const [params] = useSearchParams();
  const flow = data.flows.find((f) => f.id === id);
  if (!flow) return <Navigate to="/flows/greenfield" replace />;
  return (
    <DocPage full crumb="Flows" title={flow.title} lede={<>{flow.tagline} {flow.when}</>}>
        <nav className="flow-tabs" aria-label="Flows">
          {data.flows.map((f) => (
            <Link key={f.id} to={`/flows/${f.id}`} className={f.id === flow.id ? "on" : ""}>
              {f.title}
            </Link>
          ))}
        </nav>
        <p className="muted">
          Open any step to see what the skill does, why the step matters and what you get. Answer the
          questions on the line to see the steps that apply to your change.
        </p>
        <FlowDiagram key={flow.id} flow={flow} initialStep={params.get("step") ?? undefined} />
    </DocPage>
  );
}
