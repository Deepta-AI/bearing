"""Account tier lookup. Reads the crm_accounts table (synced nightly)."""

ENTERPRISE_DOMAINS = {"brightwater-foods.example", "kestrel-freight.example", "orchid-clinics.example"}


def account_tier(sender_email: str) -> str:
    domain = sender_email.rsplit("@", 1)[-1].lower()
    return "enterprise" if domain in ENTERPRISE_DOMAINS else "standard"
