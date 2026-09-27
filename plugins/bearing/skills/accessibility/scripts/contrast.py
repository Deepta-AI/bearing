#!/usr/bin/env python3
"""contrast: WCAG 2.x contrast ratio for colour pairs, measured, not quoted.

  contrast.py FG:BG[:MIN] [FG:BG[:MIN] ...]

FG and BG are #rgb or #rrggbb (the rendered colours; flatten any alpha onto
the background first). MIN is the ratio the pair needs: 4.5 for text under
18.66 px bold or 24 px regular, 3 for large text and for non-text parts
(field borders, focus rings, toggle tracks, icons). Default 4.5.

Prints one line per pair and the count line
  contrast: N pairs checked, K below minimum
and exits 1 when any pair is below its minimum, an argument is malformed,
or zero pairs were given.
"""

import sys


def channel(v):
    v = v / 255
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def luminance(hexcol):
    h = hexcol.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    if len(h) != 6:
        raise ValueError("not a #rgb or #rrggbb colour: %s" % hexcol)
    r, g, b = (channel(int(h[i : i + 2], 16)) for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(fg, bg):
    a, b = luminance(fg), luminance(bg)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


def main(args):
    checked, below, bad = 0, 0, 0
    for arg in args:
        parts = arg.split(":")
        try:
            fg, bg = parts[0], parts[1]
            need = float(parts[2]) if len(parts) > 2 else 4.5
            r = ratio(fg, bg)
        except (IndexError, ValueError) as e:
            print("bad pair %r: %s" % (arg, e))
            bad += 1
            continue
        checked += 1
        ok = r >= need
        below += 0 if ok else 1
        # The decision uses the exact ratio: 4.496 fails 4.5 even though it
        # prints as 4.50, so a near miss prints three decimals.
        shown = "%.3f" % r if not ok and round(r, 2) >= need else "%.2f" % r
        print("%s on %s: %s:1 (needs %g:1) %s" % (fg, bg, shown, need, "pass" if ok else "FAIL"))
    print("contrast: %d pairs checked, %d below minimum" % (checked, below))
    if checked == 0:
        print("contrast: nothing checked", file=sys.stderr)
        return 1
    return 1 if below or bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
