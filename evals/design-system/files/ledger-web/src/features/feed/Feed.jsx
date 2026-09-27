import { useEffect } from "react";

const events = [
  { id: 1, text: "INV-1042 paid" },
  { id: 2, text: "INV-1044 reminder sent" },
];

export function Feed() {
  useEffect(() => {
    // Deep links to the activity feed use the #feed anchor.
    if (window.location.hash === "#feed") {
      document.getElementById("feed")?.scrollIntoView();
    }
  }, []);

  return (
    <ul id="feed" style={{ background: "#fff", gap: 8, padding: "6px 12px" }}>
      {events.map((e) => (
        <li key={e.id}>{e.text}</li>
      ))}
    </ul>
  );
}
