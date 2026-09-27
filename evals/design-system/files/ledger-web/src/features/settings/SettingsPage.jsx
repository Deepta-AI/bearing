import "./Settings.css";
import { Button } from "../../components/Button.jsx";

export function SettingsPage() {
  return (
    <section>
      <h1 className="settings-title">Settings</h1>
      <div style={{ borderTop: "1px solid #d5dae1", marginTop: 28 }}>
        <p>Invoices are emailed to the billing contact on the first of the month.</p>
      </div>
      <div className="danger-zone">
        <p>Closing the account cancels every open invoice.</p>
        <Button>Close account</Button>
      </div>
    </section>
  );
}
