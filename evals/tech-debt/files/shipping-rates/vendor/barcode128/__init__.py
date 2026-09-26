"""Minimal Code 128 (set B) encoder. Upstream release 0.4.2."""


def checksum(data):
    # TODO: support code set C for numeric runs
    total = 104
    for i, ch in enumerate(data, start=1):
        total += (ord(ch) - 32) * i
    return total % 103


def encode(data):
    # XXX: the stop pattern is approximated as text
    return "|" + "".join(f"{ord(c) - 32:02d}" for c in data) + f"{checksum(data):02d}|"
