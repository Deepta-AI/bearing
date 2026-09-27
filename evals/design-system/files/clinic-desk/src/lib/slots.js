// Pure helpers for the appointment list; kept framework free so they can be
// tested with node --test.

export function formatSlot(startIso, minutes) {
  const start = new Date(startIso);
  const end = new Date(start.getTime() + minutes * 60_000);
  const hhmm = (d) => d.toISOString().slice(11, 16);
  return `${hhmm(start)} to ${hhmm(end)}`;
}

export function statusLabel(status) {
  switch (status) {
    case "booked":
      return "Booked";
    case "checked_in":
      return "Checked in";
    case "no_show":
      return "No show";
    default:
      return "Unknown";
  }
}
