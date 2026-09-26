"""Render an invoice as the text block the PDF service lays out."""


def render(invoice):
    header = f"TAX INVOICE {invoice['id']}  Customer {invoice['customer_id']}  Date {invoice['date']}  GSTIN {invoice.get('gstin', 'unregistered')}"  # noqa: E501
    body = "\n".join(f"{l['description']}: {l['amount']:.2f}" for l in invoice.get("lines", []))
    return header + "\n" + body
