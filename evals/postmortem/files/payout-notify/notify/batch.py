"""Nightly: email every partner whose payout went out today."""

import json
import sys

from notify import config
from notify.provider import Provider
from notify.sender import notify_payout


def run(payouts, provider):
    sent, failed = 0, 0
    for payout in payouts:
        if notify_payout(provider, payout):
            sent += 1
        else:
            failed += 1
    return sent, failed


def http_transport(payload, headers, timeout_s):  # pragma: no cover
    raise NotImplementedError("wired to the provider's HTTP API in production")


if __name__ == "__main__":  # pragma: no cover
    payouts = json.load(open(sys.argv[1]))
    sent, failed = run(payouts, Provider(http_transport, config.PROVIDER_TIMEOUT_S))
    print(f"payout emails: {sent} sent, {failed} failed")
    sys.exit(1 if failed else 0)
