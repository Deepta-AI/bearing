"""Limits and thresholds for claims."""

CURRENCY = "INR"

# Largest receipt we accept, in megabytes.
MAX_RECEIPT_MB = 10

# Finance policy FP-12: claims strictly below this amount skip approval.
AUTO_APPROVE_BELOW_INR = 500

ALLOWED_RECEIPT_TYPES = ("image/jpeg", "image/png", "application/pdf")
