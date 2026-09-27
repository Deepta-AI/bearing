import { createBrowserRouter, Navigate } from "react-router-dom";
import { AppShell } from "@/components/app-shell";
import { InvoicesPage } from "@/features/invoices/InvoicesPage";

export const router = createBrowserRouter([
  {
    element: <AppShell />,
    children: [
      { index: true, element: <Navigate to="/invoices" replace /> },
      { path: "invoices", element: <InvoicesPage /> },
    ],
  },
]);
