from app.db.invoice_repo import InvoiceRepo

PAGE_SIZE = 50


class InvoiceService:
    def __init__(self, conn):
        self.conn = conn
        self.repo = InvoiceRepo(conn)

    def create(self, tenant_id, customer_id, total_minor, currency):
        """Creates a draft invoice with the tenant's next number."""
        with self.conn.transaction():
            number = self.repo.next_number(tenant_id)
            invoice_id = self.repo.insert(tenant_id, customer_id, number, total_minor, currency)
        return invoice_id, number

    def list_page(self, tenant_id, page, status=None):
        page = max(page, 1)
        return self.repo.list_for_tenant(
            tenant_id, status, PAGE_SIZE, (page - 1) * PAGE_SIZE
        )

    def delete_draft(self, tenant_id, invoice_id):
        with self.conn.transaction():
            self.repo.soft_delete(tenant_id, invoice_id)
