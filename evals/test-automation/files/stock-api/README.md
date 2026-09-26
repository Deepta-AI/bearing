# stock-api

Warehouse stock levels for the shop. A small WSGI service on the standard
library only (no framework), with SQLite for storage. When an item's stock
drops below 5 the service posts a low stock alert to the operations
webhook so the buyers reorder.

Configuration comes from the environment (stock/config.py):

- `STOCK_DB` path of the SQLite file
- `STOCK_ALERT_WEBHOOK` where low stock alerts are posted
- `STOCK_ADMIN_TOKEN` token for the admin endpoints

The endpoints are described in docs/api.md.

    make run     # serves on :8000
    make test    # the test suite

Python 3.12 or later. pytest is the only dev dependency (the `dev` extra
in pyproject.toml).
