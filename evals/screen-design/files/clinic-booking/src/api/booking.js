const BASE = "https://api.clinic.example.com/v1";

export async function getSlots(clinicId, isoDate) {
  const res = await fetch(`${BASE}/clinics/${clinicId}/slots?date=${isoDate}`);
  if (!res.ok) throw new Error(`slots ${res.status}`);
  return res.json(); // { slots: ["09:30", ...] }, empty when closed or full
}

// 409 slot_taken when someone booked the slot between pick and confirm.
export async function createBooking(body) {
  const res = await fetch(`${BASE}/bookings`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw Object.assign(new Error("booking failed"), { status: res.status });
  return res.json();
}
