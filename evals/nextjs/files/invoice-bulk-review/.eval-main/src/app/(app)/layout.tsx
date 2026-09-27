import Link from "next/link";
import type { ReactNode } from "react";

export default function AppLayout({ children }: { children: ReactNode }) {
  return (
    <div>
      <nav aria-label="Main">
        <Link href="/invoices">Invoices</Link>
      </nav>
      <main>{children}</main>
    </div>
  );
}
