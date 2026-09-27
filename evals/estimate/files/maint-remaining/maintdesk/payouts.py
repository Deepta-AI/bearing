"""Vendor payouts through PayGate (ADR-0003).

Nothing here talks to PayGate yet: there is no API client, no sandbox
credentials and no vendor KYC record. The interface below is what the
close-job flow is expected to call.
"""


class PayoutError(RuntimeError):
    pass


def pay_vendor(vendor_id, amount_paise, reference):
    raise NotImplementedError("PayGate client not built yet (ADR-0003)")
