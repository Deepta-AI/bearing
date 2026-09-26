"""Settings, read from the environment. Production values: deploy/notify.env."""

import os

# Attempts after the first when the provider does not answer in time.
NOTIFY_MAX_RETRIES = int(os.environ.get("NOTIFY_MAX_RETRIES", "3"))

# How long one provider call may take before the client gives up on it.
PROVIDER_TIMEOUT_S = float(os.environ.get("PROVIDER_TIMEOUT_S", "2.0"))

PROVIDER_BASE_URL = os.environ.get("PROVIDER_BASE_URL", "https://mail-provider.example/v1")
