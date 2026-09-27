import Link from "next/link";
import type { ReactNode } from "react";

export default function AccountLayout({ children }: { children: ReactNode }) {
  return (
    <div className="account">
      <nav aria-label="Account">
        <Link href="/account/profile">Profile</Link>
        <Link href="/account/addresses">Addresses</Link>
      </nav>
      <main>{children}</main>
    </div>
  );
}
