import { ThemeToggle } from "@/components/theme-toggle";
import { AppointmentList } from "@/features/appointments/AppointmentList";

export default function App() {
  return (
    <div className="min-h-screen">
      <header className="flex items-center justify-between border-b px-6 py-4">
        <h1 className="text-xl font-semibold">Clinic Desk</h1>
        <ThemeToggle />
      </header>
      <main className="mx-auto max-w-4xl p-6">
        <AppointmentList />
      </main>
    </div>
  );
}
