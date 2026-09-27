import { NavLink, Outlet } from "react-router-dom";
import { FileText, Menu } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

// Payouts joins this list when the approvals screens are built.
const NAV = [{ to: "/invoices", label: "Invoices", icon: FileText }];

export function AppShell() {
  return (
    <div className="flex min-h-svh">
      <aside className="hidden w-60 shrink-0 border-r bg-sidebar text-sidebar-foreground md:block">
        <div className="px-4 py-5 text-sm font-semibold">Payline Ops</div>
        <nav className="flex flex-col gap-1 px-2">
          {NAV.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                cn(
                  "flex h-10 items-center gap-2 rounded-md px-3 text-sm",
                  isActive ? "bg-accent text-accent-foreground font-medium" : "hover:bg-muted",
                )
              }
            >
              <Icon className="size-4" aria-hidden /> {label}
            </NavLink>
          ))}
        </nav>
      </aside>
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex h-14 items-center gap-2 border-b px-4">
          <Button variant="ghost" size="icon" className="md:hidden" aria-label="Open navigation">
            <Menu className="size-5" />
          </Button>
          <span className="text-sm text-muted-foreground">Finance operations</span>
        </header>
        <main className="flex-1 p-4 md:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
