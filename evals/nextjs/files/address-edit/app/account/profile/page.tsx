import { getCustomer } from "@/lib/api";
import { requireSession } from "@/lib/session";
import { NameForm } from "./name-form";

export default async function ProfilePage() {
  const { customerId } = await requireSession();
  const customer = await getCustomer(customerId);
  return (
    <section>
      <h1>Profile</h1>
      <p>{customer.email}</p>
      <NameForm name={customer.name} />
    </section>
  );
}
