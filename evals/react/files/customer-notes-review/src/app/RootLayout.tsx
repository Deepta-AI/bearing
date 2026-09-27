import { Link, Outlet } from "react-router";

export function RootLayout() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="border-b border-border px-6 py-3">
        <Link to="/customers" className="font-semibold">
          Support console
        </Link>
      </header>
      <main className="px-6 py-4">
        <Outlet />
      </main>
    </div>
  );
}
