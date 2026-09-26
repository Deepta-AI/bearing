"""Settings read from the environment (values in deploy/k8s.yaml)."""

import os

DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///payhook.db")
DB_POOL_SIZE = int(os.environ.get("DB_POOL_SIZE", "4"))
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "20"))
POLL_INTERVAL_SECONDS = float(os.environ.get("POLL_INTERVAL_SECONDS", "2"))
LEASE_SECONDS = int(os.environ.get("LEASE_SECONDS", "300"))
MAX_ATTEMPTS = int(os.environ.get("MAX_ATTEMPTS", "5"))
ORDERS_API_URL = os.environ.get("ORDERS_API_URL", "http://localhost:9000")
ORDERS_API_TIMEOUT_SECONDS = float(os.environ.get("ORDERS_API_TIMEOUT_SECONDS", "30"))
METRICS_PORT = int(os.environ.get("METRICS_PORT", "9102"))
WEBHOOK_SIGNING_SECRET = os.environ.get("WEBHOOK_SIGNING_SECRET", "")
WEBHOOK_SIGNING_SECRET_PREVIOUS = os.environ.get("WEBHOOK_SIGNING_SECRET_PREVIOUS", "")
