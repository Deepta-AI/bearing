"""Map an Indian PIN code to a delivery zone: A (metro), B or C."""


def resolve_zone(pincode):  # noqa: C901
    p = str(pincode)
    if len(p) != 6 or not p.isdigit():
        raise ValueError(f"not a PIN code: {pincode!r}")
    region = int(p[:2])
    if region == 11:
        return "A"
    if region == 40:
        return "A"
    if region == 56:
        return "A"
    if region == 60:
        return "A"
    if 12 <= region <= 39:
        return "B"
    if 41 <= region <= 55:
        return "B"
    if 57 <= region <= 69:
        return "B"
    # FIXME: the north-east ranges are guessed, not taken from the carrier's zone table
    if 78 <= region <= 79:
        return "B"
    # HACK: unknown PIN codes are priced as zone C instead of being rejected
    return "C"
