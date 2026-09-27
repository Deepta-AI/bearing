"""Billing events sent to the ledger."""

from .invoices import Invoice


def issued_event(inv: Invoice, issued_at: str) -> dict:
    return {
        "event": "invoice.issued",
        "invoice_id": inv.invoice_id,
        "customer_id": inv.customer_id,
        "amount_minor": inv.total_minor(),
        "currency": inv.currency,
        "issued_at": issued_at,
    }
