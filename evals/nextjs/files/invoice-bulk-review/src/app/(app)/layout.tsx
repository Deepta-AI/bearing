import Link from "next/link";
import type { ReactNode } from "react";
import { setCurrentOrg } from "@/lib/current-org";
import { requireSession } from "@/lib/session";

export default async function AppLayout({ children }: { children: ReactNode }) {
  const session = await requireSession();
  setCurrentOrg(session.orgId);
  return (
    <div>
      <nav aria-label="Main">
        <Link href="/invoices">Invoices</Link>
      </nav>
      <main>{children}</main>
    </div>
  );
}
