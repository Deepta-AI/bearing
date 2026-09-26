"""Send one partner the payout email."""

import logging

from notify import config
from notify.provider import ProviderTimeout

log = logging.getLogger("notify.sender")


def notify_payout(provider, payout, max_retries=None):
    """Return the provider message id, or None when every attempt timed out."""
    retries = config.NOTIFY_MAX_RETRIES if max_retries is None else max_retries
    data = {"amount_paise": payout["amount_paise"], "reference": payout["id"]}
    for attempt in range(retries + 1):
        try:
            return provider.send(payout["email"], "payout_sent", data)
        except ProviderTimeout:
            log.warning("payout %s: provider timeout on attempt %d", payout["id"], attempt + 1)
    log.error("payout %s: gave up after %d attempts", payout["id"], retries + 1)
    return None
