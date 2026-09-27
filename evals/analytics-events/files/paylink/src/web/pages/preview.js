import { renderInvoice } from '../components/invoice-view.js';

// The merchant's preview of an invoice before sending it.
export function renderPreview(invoice) {
  return `<main>
<aside class="preview-note">Preview: this is what your customer sees.</aside>
${renderInvoice(invoice)}
</main>`;
}
