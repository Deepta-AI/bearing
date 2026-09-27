import { BrowserRouter, Link, Route, Routes } from "react-router-dom";
import { ThemeToggle } from "./theme";
import { ShipmentsPage } from "./pages/Shipments";
import { ShipmentTrackingPage } from "./pages/ShipmentTracking";

export function App() {
  return (
    <BrowserRouter>
      <header className="flex items-center justify-between border-b px-6 py-3">
        <Link to="/shipments" className="font-semibold">
          Haulbook
        </Link>
        <ThemeToggle />
      </header>
      <main className="mx-auto max-w-6xl px-6 py-8">
        <Routes>
          <Route path="/shipments" element={<ShipmentsPage />} />
          <Route path="/shipments/:id" element={<ShipmentTrackingPage />} />
          <Route path="*" element={<ShipmentsPage />} />
        </Routes>
      </main>
    </BrowserRouter>
  );
}
