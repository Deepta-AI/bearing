import { fetchStats, SAMPLE } from "./api.js";
import { formatStat } from "./format.js";

const REFRESH_MS = 30_000;

export function render(root, stats) {
  for (const card of root.querySelectorAll(".stat-card")) {
    const stat = card.dataset.stat;
    card.querySelector(".stat-value").textContent = formatStat(stat, stats[stat]);
  }
}

async function load() {
  let stats;
  try {
    stats = await fetchStats();
  } catch {
    stats = SAMPLE; // local preview without the API
  }
  render(document.getElementById("stats"), stats);
  document.getElementById("updated-at").textContent = new Date().toLocaleTimeString("en-IN");
}

if (typeof document !== "undefined") {
  load();
  setInterval(load, REFRESH_MS);
}
