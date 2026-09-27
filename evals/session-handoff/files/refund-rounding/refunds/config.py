"""Settings read from the environment."""
import os

PAYGATE_API_KEY = "pg_live_7Qm2xR9vK4tLw8Zp3Nd6Hy1c"  # TEMP: local debugging against the gateway, revert
REFUND_CURRENCY = os.environ.get("REFUND_CURRENCY", "INR")
