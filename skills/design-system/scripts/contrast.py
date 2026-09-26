#!/usr/bin/env python3
"""contrast: check the light and dark roles in tokens.json before any theme
exists, so the design system's contrast line is counted, not claimed.

  contrast.py [--tokens docs/design/tokens.json] [--strict-hex]

Uses themes's theme-lint.py (the one contrast calculator in the kit) for
the colour maths, the role list and the pair table: text pairs need 4.5:1,
edges and focus 3:1, and note pairs are reported only. Every role must
resolve in both modes. Prints each problem and the count line

  contrast: N pairs checked (light L, dark D), K below minimum (must be 0), AAA body pairs: M

and exits 1 on any problem, when the tokens file is missing, or when zero
pairs were checked. theme-lint.py is found next to this skill in the plugin
(../../themes/templates/theme-lint.py) or at --theme-lint.
"""

import argparse
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_LINT = os.path.join(HERE, "..", "..", "themes", "templates", "theme-lint.py")


def load_theme_lint(path):
    # No __pycache__ next to themes's template: that folder is copied
    # into projects.
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("theme_lint", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", default="docs/design/tokens.json")
    ap.add_argument("--theme-lint", default=DEFAULT_LINT)
    ap.add_argument("--strict-hex", action="store_true")
    args = ap.parse_args()

    if not os.path.isfile(args.theme_lint):
        print(
            "contrast: theme-lint.py not found at %s" % args.theme_lint, file=sys.stderr
        )
        sys.exit(1)
    tl = load_theme_lint(args.theme_lint)
    try:
        with open(args.tokens) as f:
            tokens = json.load(f)
        roles = tokens["color"]["roles"]
        resolver = tl.Resolver(tokens, args.strict_hex)
    except (OSError, ValueError, KeyError, TypeError) as e:
        print(
            "contrast: cannot read roles from %s: %s" % (args.tokens, e),
            file=sys.stderr,
        )
        print("contrast: 0 pairs checked, nothing checked", file=sys.stderr)
        sys.exit(1)

    counts, below, aaa, problems = {}, 0, 0, 0
    for mode in ("light", "dark"):
        if mode not in roles:
            print("%s: mode missing from color.roles" % mode)
            problems += 1
            counts[mode] = 0
            continue
        r = tl.lint_theme(mode, mode, mode, roles[mode], {}, resolver, {}, [])
        counts[mode] = len(r["contrast"])
        for p in r["contrast"]:
            if p["class"] == "body" and p["ratio"] >= 7.0:
                aaa += 1
            if not p["pass"]:
                below += 1
        for msg in r["problems"]:
            print("%s: %s" % (mode, msg))
        problems += len(r["problems"])

    n = sum(counts.values())
    print(
        "contrast: %d pairs checked (light %d, dark %d), %d below minimum (must be 0), AAA body pairs: %d"
        % (n, counts["light"], counts["dark"], below, aaa)
    )
    if n == 0:
        print("contrast: 0 pairs checked, nothing checked", file=sys.stderr)
        sys.exit(1)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
