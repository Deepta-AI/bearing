from app.db.errors import DuplicateKey, constraint_name, is_unique_violation


class CustomerRepo:
    def __init__(self, conn):
        self.conn = conn

    def insert(self, tenant_id, name, email):
        try:
            cur = self.conn.execute(
                "INSERT INTO customers (tenant_id, name, email) VALUES (%s, %s, %s) RETURNING id",
                (tenant_id, name, email),
            )
        except Exception as exc:
            if is_unique_violation(exc):
                raise DuplicateKey(constraint_name(exc)) from exc
            raise
        return cur.fetchone()[0]
