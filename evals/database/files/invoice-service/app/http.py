"""Thin handlers; the router in the platform shell calls these."""

from app.services.invoices import InvoiceService


def list_invoices(conn, tenant_id, query):
    """GET /tenants/{tenant_id}/invoices?page=N&status=S"""
    page = int(query.get("page", "1"))
    rows = InvoiceService(conn).list_page(tenant_id, page, query.get("status"))
    return 200, {"page": page, "invoices": [r.__dict__ for r in rows]}


def create_invoice(conn, tenant_id, body):
    """POST /tenants/{tenant_id}/invoices"""
    invoice_id, number = InvoiceService(conn).create(
        tenant_id, body["customer_id"], body["total_minor"], body["currency"]
    )
    return 201, {"id": invoice_id, "number": number}
