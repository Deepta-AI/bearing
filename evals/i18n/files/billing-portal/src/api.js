// Thin wrapper over the billing API. Error bodies are
// { "error": { "code": "...", "message": "..." } } (docs/api.md).

async function request(path, options = {}) {
  const res = await fetch(`/api${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(body.error?.message || 'Request failed');
    err.code = body.error?.code;
    throw err;
  }
  return body;
}

// { id, name, email, preferredLocale }  preferredLocale is null until the
// customer picks a language in their profile.
export const getMe = () => request('/me');

export const listInvoices = () => request('/invoices');

export const payInvoice = (id) =>
  request(`/invoices/${id}/pay`, { method: 'POST' });
