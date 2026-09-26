"""Runtime settings for shopfront. These values ship with the code."""

import os

DATABASE_PATH = os.environ.get("SHOPFRONT_DB", ":memory:")

# Connections held by each worker process. Production runs three pods with
# four worker processes each, so the primary sees 12 x DB_POOL_SIZE.
DB_POOL_SIZE = 20

# How long a request waits for a free connection before giving up.
DB_POOL_TIMEOUT_S = 2.0
