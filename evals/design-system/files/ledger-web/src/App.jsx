import { InvoiceList } from "./features/billing/InvoiceList.jsx";
import { SettingsPage } from "./features/settings/SettingsPage.jsx";
import { Feed } from "./features/feed/Feed.jsx";

export function App() {
  const page = window.location.pathname;
  if (page.startsWith("/settings")) return <SettingsPage />;
  if (page.startsWith("/activity")) return <Feed />;
  return <InvoiceList />;
}
