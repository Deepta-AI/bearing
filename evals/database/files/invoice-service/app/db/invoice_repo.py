from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class InvoiceRow:
    id: int
    number: int
    status: str
    total_minor: int
    currency: str
    issued_at: datetime | None


LIST_COLUMNS = "id, number, status, total_minor, currency, issued_at"


class InvoiceRepo:
    def __init__(self, conn):
        self.conn = conn

    def next_number(self, tenant_id):
        cur = self.conn.execute(
            "SELECT coalesce(max(number), 0) + 1 FROM invoices "
            "WHERE tenant_id = %s AND deleted_at IS NULL",
            (tenant_id,),
        )
        return cur.fetchone()[0]

    def insert(self, tenant_id, customer_id, number, total_minor, currency):
        cur = self.conn.execute(
            "INSERT INTO invoices (tenant_id, customer_id, number, total_minor, currency) "
            "VALUES (%s, %s, %s, %s, %s) RETURNING id",
            (tenant_id, customer_id, number, total_minor, currency),
        )
        return cur.fetchone()[0]

    def list_for_tenant(self, tenant_id, status, limit, offset):
        cur = self.conn.execute(
            f"SELECT {LIST_COLUMNS} FROM invoices "
            "WHERE tenant_id = %s AND deleted_at IS NULL "
            "AND (%s::text IS NULL OR status = %s) "
            "ORDER BY issued_at DESC, id DESC "
            "LIMIT %s OFFSET %s",
            (tenant_id, status, status, limit, offset),
        )
        return [InvoiceRow(*r) for r in cur.fetchall()]

    def export_created_between(self, tenant_id, start, end):
        """Monthly export for the accounting feed; served by idx_invoices_tenant_created."""
        cur = self.conn.execute(
            f"SELECT {LIST_COLUMNS} FROM invoices "
            "WHERE tenant_id = %s AND created_at >= %s AND created_at < %s "
            "ORDER BY created_at, id",
            (tenant_id, start, end),
        )
        return [InvoiceRow(*r) for r in cur.fetchall()]

    def soft_delete(self, tenant_id, invoice_id):
        self.conn.execute(
            "UPDATE invoices SET deleted_at = now() "
            "WHERE tenant_id = %s AND id = %s AND status = 'draft' AND deleted_at IS NULL",
            (tenant_id, invoice_id),
        )
