// Which days a clinic takes bookings, and the slots on a day.
// Clinics open 09:00 to 17:00 in 30 minute slots, Monday to Saturday.

export const HOLIDAYS_2026 = ["2026-10-02", "2026-10-20", "2026-11-09", "2026-12-25"];

export function isOpen(isoDate) {
  const d = new Date(`${isoDate}T00:00:00Z`);
  if (d.getUTCDay() === 0) return false;
  return !HOLIDAYS_2026.includes(isoDate);
}

export function daySlots(isoDate, booked = []) {
  if (!isOpen(isoDate)) return [];
  const out = [];
  for (let m = 9 * 60; m < 17 * 60; m += 30) {
    const hhmm = `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
    if (!booked.includes(hhmm)) out.push(hhmm);
  }
  return out;
}
