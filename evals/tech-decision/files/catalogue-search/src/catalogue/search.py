"""Product search over the products.search tsvector column (ADR-004)."""

SEARCH_SQL = """
SELECT id, name, price_paise, ts_rank(search, q) AS rank
FROM products, websearch_to_tsquery('english', %(q)s) AS q
WHERE search @@ q AND active
ORDER BY rank DESC
LIMIT %(limit)s
"""


def search(conn, query: str, limit: int = 24) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(SEARCH_SQL, {"q": query, "limit": limit})
        cols = [c.name for c in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]
