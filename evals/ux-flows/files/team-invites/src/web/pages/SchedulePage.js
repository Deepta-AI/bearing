export function SchedulePage({ week, shifts = [] }) {
  if (!shifts.length) {
    return `<main><h1>Week of ${week}</h1><p>No shifts yet. <a href="/schedule/new">Add the first shift</a></p></main>`;
  }
  return `<main><h1>Week of ${week}</h1><ul>${shifts.map((s) => `<li>${s.label}</li>`).join('')}</ul></main>`;
}
