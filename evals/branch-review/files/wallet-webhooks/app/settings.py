import os

WEBHOOK_SECRET = os.environ.get("WEBHOOK_SECRET", "dev-secret")
DB_PATH = os.environ.get("DB_PATH", "wallet.db")

# Largest webhook body we accept; the provider's payloads are under 4 KB.
MAX_BODY_BYTES = 64 * 1024

# Deliveries signed longer ago than this are rejected as replays
# (docs/provider-webhooks.md).
REPLAY_WINDOW_SECONDS = 300 * 60

# How long a processed event id is remembered for de-duplication.
DEDUPE_TTL_HOURS = 24
