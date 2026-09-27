// Monthly invoice per clinic: one line per completed booking. PDF rendering next.
export function invoiceLines(bookings, clinicId, month) {
  return bookings
    .filter((b) => b.clinicId === clinicId && b.status === "completed" && b.slot.startsWith(month))
    .map((b) => ({ bookingId: b.id, slot: b.slot }));
}
