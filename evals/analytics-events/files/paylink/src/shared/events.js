// The event catalogue. It mirrors docs/analytics/EVENT_SHEET.md row for row;
// test/catalogue.test.js fails when the two differ.
// Types: string, integer, boolean, or enum(a,b,...).
export const EVENTS = {
  screen_viewed: { screen: 'enum(invoices,invoice_preview,pay,settings)' },
  consent_updated: { analytics: 'boolean' },
  signed_up: { plan: 'enum(free,pro)' },
  logged_in: { method: 'enum(password,magic_link)' },
  invoice_created: {
    invoice_id: 'string',
    currency: 'enum(INR,USD)',
    amount_minor: 'integer',
    line_count: 'integer',
  },
  invoice_sent: { invoice_id: 'string', channel: 'enum(email,link)' },
};

function checkType(type, value) {
  if (type === 'string') return typeof value === 'string' && value.length <= 200;
  if (type === 'integer') return Number.isInteger(value);
  if (type === 'boolean') return typeof value === 'boolean';
  const m = /^enum\((.*)\)$/.exec(type);
  if (m) return m[1].split(',').includes(value);
  throw new Error(`unknown property type ${type}`);
}

// Throws when the event is not in the catalogue or its properties do not
// match: every property present, none extra, each of the right type.
export function validate(event, props) {
  const schema = EVENTS[event];
  if (!schema) throw new Error(`analytics: unknown event ${event}`);
  for (const key of Object.keys(props)) {
    if (!(key in schema)) throw new Error(`analytics: ${event} has no property ${key}`);
  }
  for (const [key, type] of Object.entries(schema)) {
    if (!(key in props)) throw new Error(`analytics: ${event} is missing ${key}`);
    if (!checkType(type, props[key])) {
      throw new Error(`analytics: ${event}.${key} is not ${type}`);
    }
  }
}
