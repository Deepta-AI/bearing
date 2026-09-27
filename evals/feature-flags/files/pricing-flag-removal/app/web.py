"""Page entry points, called by the server with the signed-in account."""

import os

from app.flags import Flags
from app.pricing.page import render_pricing


def pricing_page(account_id: str, environ=os.environ) -> str:
    flags = Flags.from_env(environ).for_account(account_id)
    return render_pricing(flags, environ.get("CURRENCY", "USD"), environ.get("REGION", "us"))
