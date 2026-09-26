"""Render a plain-text shipping label with a Code 128 barcode line."""

from barcode128 import encode  # type: ignore[import-untyped]

WIDTH = 48


def render_label(order_id, address, weight_kg):
    # TODO: label width assumes 4x6 inch printers; the new hub printers are 4x4
    lines = [
        f"ORDER {order_id}".ljust(WIDTH),
        address[:WIDTH].ljust(WIDTH),
        f"{weight_kg:.1f} kg".ljust(WIDTH),
        encode(order_id)[:WIDTH].ljust(WIDTH),
    ]
    return "\n".join(lines)
