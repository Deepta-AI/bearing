import { useState } from "react";
import { Link } from "react-router";
import { useCustomers } from "./hooks";

export function CustomersPage() {
  const [q, setQ] = useState("");
  const { data, isPending, isError, refetch } = useCustomers(q);

  return (
    <section aria-labelledby="customers-heading">
      <h1 id="customers-heading" className="mb-4 text-xl font-semibold">
        Customers
      </h1>
      <label className="mb-4 block">
        <span className="block text-sm text-muted-foreground">Search by name or email</span>
        <input
          type="search"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          className="rounded-md border border-border px-2 py-1"
        />
      </label>
      {isPending ? (
        <p role="status">Loading customers...</p>
      ) : isError ? (
        <div role="alert" className="text-destructive">
          Could not load customers.{" "}
          <button type="button" className="underline" onClick={() => refetch()}>
            Retry
          </button>
        </div>
      ) : data.length === 0 ? (
        <p role="status">No customers match.</p>
      ) : (
        <ul>
          {data.map((c) => (
            <li key={c.id}>
              <Link to={`/customers/${c.id}`} className="text-primary underline">
                {c.name}
              </Link>{" "}
              <span className="text-muted-foreground">{c.email}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
