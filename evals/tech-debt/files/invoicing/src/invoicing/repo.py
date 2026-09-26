"""Invoice storage. The real service uses Postgres; this is the in-memory shape."""


class InvoiceRepo:
    def __init__(self, db):
        self.db = db

    def list_invoices(self, customer_id):
        # TODO: N+1 query, one lookup per invoice for its lines; the customer page takes 3 s
        invoices = [i for i in self.db["invoices"] if i["customer_id"] == customer_id]
        for inv in invoices:
            inv["lines"] = [l for l in self.db["lines"] if l["invoice_id"] == inv["id"]]
        return invoices
