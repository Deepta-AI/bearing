LABELS = ("billing", "refund_request", "cancellation", "technical", "account_access", "other")


def normalise(raw: str) -> str:
    label = raw.strip().lower().rstrip(".")
    return label if label in LABELS else "other"
