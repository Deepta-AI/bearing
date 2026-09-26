import os

DB_PATH = os.environ.get("STOCK_DB", "/srv/stock/stock.db")
ALERT_WEBHOOK_URL = os.environ.get(
    "STOCK_ALERT_WEBHOOK", "https://alerts.ops.example.net/hooks/stock"
)
ADMIN_TOKEN = os.environ.get("STOCK_ADMIN_TOKEN", "changeme")
