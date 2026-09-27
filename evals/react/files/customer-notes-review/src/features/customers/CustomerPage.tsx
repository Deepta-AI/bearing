import { Link, useParams } from "react-router";
import { NotesPanel } from "@/features/notes/NotesPanel";
import { useCustomer } from "./hooks";

export function CustomerPage() {
  const { customerId = "" } = useParams();
  const { data, isPending, isError, refetch } = useCustomer(customerId);

  if (isPending) return <p role="status">Loading customer...</p>;
  if (isError)
    return (
      <div role="alert" className="text-destructive">
        Could not load this customer.{" "}
        <button type="button" className="underline" onClick={() => refetch()}>
          Retry
        </button>
      </div>
    );

  return (
    <section aria-labelledby="customer-heading">
      <Link to="/customers" className="text-primary underline">
        Back to customers
      </Link>
      <h1 id="customer-heading" className="my-4 text-xl font-semibold">
        {data.name}
      </h1>
      <dl className="grid grid-cols-[8rem_1fr] gap-y-1 text-sm">
        <dt className="text-muted-foreground">Email</dt>
        <dd>{data.email}</dd>
        <dt className="text-muted-foreground">Phone</dt>
        <dd>{data.phone ?? "Not given"}</dd>
      </dl>
      {data.linkedAccounts.length > 0 && (
        <nav aria-label="Linked accounts" className="mt-4 text-sm">
          <h2 className="font-semibold">Linked accounts</h2>
          <ul>
            {data.linkedAccounts.map((a) => (
              <li key={a.id}>
                <Link to={`/customers/${a.id}`} className="text-primary underline">
                  {a.name}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      )}
      <NotesPanel customerId={customerId} />
    </section>
  );
}
