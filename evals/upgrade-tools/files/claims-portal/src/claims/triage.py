"""Route an incoming claim to a queue."""

FAST_TRACK_LIMIT = 50_000  # rupees; claims at or under this skip review


def queue_for(claim: dict) -> str:
    if claim.get("fraud_flag"):
        return "investigation"
    if claim["amount"] <= FAST_TRACK_LIMIT and claim.get("documents_complete"):
        return "fast-track"
    return "standard"
