import { layout } from "./layout.js";

// Admin only. Owned by the reporting team.
export function reportsPage(rows) {
  const body = `
<h1>Signups by week</h1>
<img src="/public/signups-chart.png">
<table>
  ${rows.map((r) => `<tr><td>${r.week}</td><td>${r.count}</td></tr>`).join("\n  ")}
</table>`;
  return layout({ title: "Reports", body });
}
