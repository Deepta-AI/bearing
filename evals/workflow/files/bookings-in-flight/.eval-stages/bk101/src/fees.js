// Fee for cancelling a booking, in paise.
export function cancellationFee(slotIso, nowIso, clinicFee) {
  const hours = (Date.parse(slotIso) - Date.parse(nowIso)) / 3_600_000;
  return hours < 24 ? clinicFee : 0;
}
