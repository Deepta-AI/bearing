// Slot booking with an in-memory store. Times are ISO strings in UTC.
export function createStore() {
  const bookings = new Map();
  let next = 1;
  return {
    book(clinicId, slot, patientId) {
      for (const b of bookings.values()) {
        if (b.clinicId === clinicId && b.slot === slot && b.status === "booked") {
          throw new Error("slot taken");
        }
      }
      const id = `bk_${next++}`;
      bookings.set(id, { id, clinicId, slot, patientId, status: "booked" });
      return bookings.get(id);
    },
    cancel(id) {
      const b = bookings.get(id);
      if (!b) throw new Error("not found");
      b.status = "cancelled";
      return b;
    },
    get(id) {
      return bookings.get(id);
    },
  };
}
