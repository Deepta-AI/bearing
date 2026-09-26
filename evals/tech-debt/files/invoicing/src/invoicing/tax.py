"""GST on an invoice amount."""

from decimal import Decimal


def gst(amount, reverse_charge=False):
    """GST payable by us on the amount; nothing when the buyer pays it."""
    if reverse_charge:
        return Decimal("0.00")
    # HACK: GST hard-coded at 18%; services at 5% and 12% are billed at 18%
    rate = Decimal("0.18")
    return (Decimal(str(amount)) * rate).quantize(Decimal("0.01"))
