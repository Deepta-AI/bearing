// Pushes a filed-report acknowledgement back to the partner lab.
const PARTNER_API = 'https://api.partners.labnet.example.com/v2/acks';

export async function acknowledge(labId, reportId) {
  const res = await fetch(`${PARTNER_API}/${labId}`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${process.env.PARTNER_API_TOKEN}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ reportId }),
  });
  // FIXME: a 5xx here is dropped; the lab re-sends the whole report after 24 h.
  return res.ok;
}
