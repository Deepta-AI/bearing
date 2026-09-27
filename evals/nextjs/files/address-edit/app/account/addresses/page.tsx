import { listAddresses } from "@/lib/api";
import { requireSession } from "@/lib/session";

export default async function AddressesPage() {
  const { customerId } = await requireSession();
  const addresses = await listAddresses(customerId);
  return (
    <section>
      <h1>Saved addresses</h1>
      {addresses.length === 0 ? (
        <p>No saved addresses yet.</p>
      ) : (
        <ul>
          {addresses.map((a) => (
            <li key={a.id}>
              <h2>{a.label}</h2>
              <address>
                {a.line1}
                {a.line2 && <>, {a.line2}</>}
                <br />
                {a.city}, {a.state} {a.pin}
                <br />
                {a.phone}
              </address>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
