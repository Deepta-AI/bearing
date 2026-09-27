import { createBrowserRouter, Navigate } from "react-router";
import { CustomerPage } from "@/features/customers/CustomerPage";
import { CustomersPage } from "@/features/customers/CustomersPage";
import { RootLayout } from "./RootLayout";

export const router = createBrowserRouter([
  {
    path: "/",
    element: <RootLayout />,
    children: [
      { index: true, element: <Navigate to="/customers" replace /> },
      { path: "customers", element: <CustomersPage /> },
      { path: "customers/:customerId", element: <CustomerPage /> },
    ],
  },
]);
