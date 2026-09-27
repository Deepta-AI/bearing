// Waitlist per clinic slot, first come first served.
export function createWaitlist() {
  const lists = new Map();
  return {
    add(clinicId, slot, patientId) {
      const key = `${clinicId}|${slot}`;
      const l = lists.get(key) ?? [];
      l.push(patientId);
      lists.set(key, l);
      return l.length;
    },
    list(clinicId, slot) {
      return [...(lists.get(`${clinicId}|${slot}`) ?? [])];
    },
  };
}
