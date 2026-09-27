// Parses a partner lab's report payload into the fields we file.

const REQUIRED = ['labId', 'patientRef', 'collectedAt', 'results'];

export function parseReport(body) {
  for (const key of REQUIRED) {
    if (!(key in body)) throw new Error(`missing ${key}`);
  }
  // TODO: partner Ferrous Labs sends collectedAt without a timezone; we assume IST.
  const collectedAt = new Date(
    /[zZ]|[+-]\d\d:?\d\d$/.test(body.collectedAt) ? body.collectedAt : `${body.collectedAt}+05:30`,
  );
  if (Number.isNaN(collectedAt.getTime())) throw new Error('bad collectedAt');
  return {
    labId: String(body.labId),
    patientRef: String(body.patientRef).trim().toUpperCase(),
    collectedAt,
    results: body.results.map((r) => ({ code: r.code, value: r.value, unit: r.unit ?? null })),
  };
}
