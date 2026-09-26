#!/usr/bin/env python3
"""theme-lint: every theme resolves every role, and every checked pair keeps
its contrast. Also writes the theme preview page.

Usage:
  python3 scripts/theme-lint.py [--tokens docs/design/tokens.json]
      [--themes docs/design/themes] [--preview docs/design/themes/preview.html
      --template scripts/preview.html] [--strict-hex]

Exit 1 when any theme fails, when zero themes were found, or when a base
mode in tokens.json fails. Prints one line per theme and a final count
line: theme-lint: T themes, R roles overridden, P pairs checked, F failures.
Installed by themes as scripts/theme-lint.py.
"""

import argparse
import json
import math
import os
import re
import sys

ROLES = [
    "bg",
    "bg-subtle",
    "surface",
    "surface-raised",
    "overlay",
    "text",
    "text-muted",
    "text-disabled",
    "link",
    "border",
    "border-strong",
    "accent",
    "accent-hover",
    "accent-active",
    "on-accent",
    "accent-subtle",
    "success",
    "on-success",
    "success-subtle",
    "warning",
    "on-warning",
    "warning-subtle",
    "danger",
    "on-danger",
    "danger-subtle",
    "info",
    "on-info",
    "info-subtle",
    "focus",
    "selection",
]
THEME_KEYS = {
    "name",
    "kind",
    "extends",
    "description",
    "roles",
    "logo",
    "display",
    "valid",
}
KINDS = {"light", "dark", "high-contrast", "brand", "tenant", "seasonal", "campaign"}

# (foreground, background, minimum ratio, class). Class "body" pairs carry the
# AAA rule: where the base mode reaches 7:1 the theme must too. "ui" pairs are
# non-text edges and indicators (WCAG 1.4.11). "note" pairs are reported only.
PAIRS = [
    ("text", "bg", 4.5, "body"),
    ("text", "bg-subtle", 4.5, "body"),
    ("text", "surface", 4.5, "body"),
    ("text", "surface-raised", 4.5, "body"),
    ("text-muted", "bg", 4.5, "text"),
    ("text-muted", "surface", 4.5, "text"),
    ("text-muted", "surface-raised", 4.5, "text"),
    ("link", "bg", 4.5, "text"),
    ("link", "surface", 4.5, "text"),
    ("on-accent", "accent", 4.5, "text"),
    ("on-accent", "accent-hover", 4.5, "text"),
    ("on-accent", "accent-active", 4.5, "text"),
    ("on-success", "success", 4.5, "text"),
    ("on-warning", "warning", 4.5, "text"),
    ("on-danger", "danger", 4.5, "text"),
    ("on-info", "info", 4.5, "text"),
    ("text", "accent-subtle", 4.5, "text"),
    ("text", "success-subtle", 4.5, "text"),
    ("text", "warning-subtle", 4.5, "text"),
    ("text", "danger-subtle", 4.5, "text"),
    ("text", "info-subtle", 4.5, "text"),
    ("text", "selection", 4.5, "text"),
    ("accent", "bg", 3.0, "ui"),
    ("accent", "surface", 3.0, "ui"),
    ("border-strong", "bg", 3.0, "ui"),
    ("border-strong", "surface", 3.0, "ui"),
    ("focus", "bg", 3.0, "ui"),
    ("focus", "surface", 3.0, "ui"),
    ("focus", "surface-raised", 3.0, "ui"),
    ("focus", "accent", 0.0, "note"),
    ("danger", "surface", 3.0, "ui"),
    ("success", "surface", 3.0, "ui"),
    ("text-disabled", "surface", 0.0, "note"),
    ("text-disabled", "bg", 0.0, "note"),
]


def parse_oklch(s):
    m = re.match(
        r"oklch\(\s*([0-9.]+)(%?)\s+([0-9.]+)\s+([0-9.]+)(?:\s*/\s*([0-9.]+%?))?\s*\)",
        s.strip(),
    )
    if not m:
        raise ValueError("bad oklch: %s" % s)
    L = float(m.group(1)) / (100.0 if m.group(2) else 1.0)
    return L, float(m.group(3)), float(m.group(4)), m.group(5)


def oklch_to_linear(L, C, h):
    a, b = C * math.cos(math.radians(h)), C * math.sin(math.radians(h))
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_**3, m_**3, s_**3
    return (
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )


def gamma(c):
    c = min(max(c, 0.0), 1.0)
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def degamma(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_linear(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(ch * 2 for ch in h)
    return tuple(degamma(int(h[i : i + 2], 16) / 255.0) for i in (0, 2, 4))


def hex_drift(a, b):
    """Largest per-channel difference between two hex colours, in 0..255 steps."""
    a, b = a.lstrip("#"), b.lstrip("#")
    return max(abs(int(a[i : i + 2], 16) - int(b[i : i + 2], 16)) for i in (0, 2, 4))


def linear_to_hex(lin):
    return "#" + "".join("%02x" % round(gamma(c) * 255) for c in lin)


def luminance(lin):
    r, g, b = (min(max(c, 0.0), 1.0) for c in lin)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


class Resolver:
    def __init__(self, tokens, strict_hex):
        self.prims = tokens["color"]["primitives"]
        self.strict_hex = strict_hex

    def value(self, v, where, problems):
        """Return (linear rgb, hex, oklch string, alpha) or None."""
        if isinstance(v, str) and re.match(r"^[a-z][a-z0-9-]*\.(\d+)$", v):
            scale, step = v.split(".")
            node = self.prims.get(scale, {}).get(step)
            if node is None:
                problems.append("%s: primitive %s does not exist" % (where, v))
                return None
            return self.value(node, where, problems)
        if isinstance(v, dict) and "oklch" in v:
            L, C, h, alpha = parse_oklch(v["oklch"])
            lin = oklch_to_linear(L, C, h)
            clipped = any(c < -0.01 or c > 1.01 for c in lin)
            if clipped:
                problems.append(
                    "%s: %s is outside sRGB; lower the chroma" % (where, v["oklch"])
                )
            computed = linear_to_hex(lin)
            given = v.get("hex", "").lower()
            if given and self.strict_hex and hex_drift(given, computed) > 1:
                problems.append(
                    "%s: hex %s drifts from oklch by more than one step (computed %s)"
                    % (where, given, computed)
                )
            return lin, given or computed, v["oklch"], alpha
        if isinstance(v, str) and v.startswith("oklch("):
            L, C, h, alpha = parse_oklch(v)
            lin = oklch_to_linear(L, C, h)
            return lin, linear_to_hex(lin), v, alpha
        if isinstance(v, str) and re.match(r"^#[0-9a-fA-F]{6}$", v):
            problems.append(
                "%s: %s is hex only; state the colour in oklch with the hex as fallback"
                % (where, v)
            )
            return hex_to_linear(v), v.lower(), "", None
        problems.append("%s: cannot resolve %r" % (where, v))
        return None


def lint_theme(
    name, kind, base_name, base_roles, overrides, resolver, base_ratios, extra
):
    problems = list(extra)
    resolved = dict(base_roles)
    for role, v in overrides.items():
        if role not in ROLES:
            problems.append(
                "unknown role '%s' (themes override semantic roles only)" % role
            )
        resolved[role] = v
    colours = {}
    for role in ROLES:
        if role not in resolved:
            problems.append("role '%s' undefined" % role)
            continue
        c = resolver.value(resolved[role], "role %s" % role, problems)
        if c:
            colours[role] = c
    pairs = []
    for fg, bg, minimum, cls in PAIRS:
        if fg not in colours or bg not in colours:
            continue
        ratio = contrast(colours[fg][0], colours[bg][0])
        need = minimum
        if kind == "high-contrast":
            need = 7.0 if cls in ("body", "text") else 4.5
        elif cls == "body" and base_ratios.get((fg, bg), 0) >= 7.0:
            need = 7.0
        ok = cls == "note" or ratio >= need
        if not ok:
            problems.append("%s on %s is %.2f:1, needs %.1f:1" % (fg, bg, ratio, need))
        pairs.append(
            {
                "fg": fg,
                "bg": bg,
                "ratio": round(ratio, 2),
                "min": need,
                "pass": ok,
                "class": cls,
            }
        )
    return {
        "name": name,
        "kind": kind,
        "extends": base_name,
        "overridden": sorted(k for k in overrides if k in ROLES),
        "roles": {r: {"hex": c[1], "oklch": c[2]} for r, c in colours.items()},
        "contrast": pairs,
        "problems": problems,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", default="docs/design/tokens.json")
    ap.add_argument("--themes", default="docs/design/themes")
    ap.add_argument("--preview", help="write the preview page here")
    ap.add_argument("--template", default="scripts/preview.html")
    ap.add_argument(
        "--strict-hex",
        action="store_true",
        help="fail when a hex fallback drifts from its oklch",
    )
    args = ap.parse_args()

    with open(args.tokens) as f:
        tokens = json.load(f)
    resolver = Resolver(tokens, args.strict_hex)
    base_roles = tokens["color"]["roles"]
    allowed_faces = (
        tokens.get("font", {}).get("families", {}).get("tenantDisplayFaces", [])
    )

    results = []
    base_ratios = {}
    for mode in ("light", "dark"):
        r = lint_theme(
            "base:" + mode, mode, mode, base_roles[mode], {}, resolver, {}, []
        )
        base_ratios[mode] = {(p["fg"], p["bg"]): p["ratio"] for p in r["contrast"]}
        results.append(r)

    files = (
        sorted(fn for fn in os.listdir(args.themes) if fn.endswith(".json"))
        if os.path.isdir(args.themes)
        else []
    )
    for fn in files:
        path = os.path.join(args.themes, fn)
        with open(path) as f:
            theme = json.load(f)
        extra = []
        name = theme.get("name", fn[:-5])
        if name != fn[:-5]:
            extra.append("name '%s' differs from file name '%s'" % (name, fn[:-5]))
        for k in theme:
            if k not in THEME_KEYS:
                extra.append(
                    "key '%s' is not allowed in a theme (roles, logo, display and validity only)"
                    % k
                )
        kind = theme.get("kind", "brand")
        if kind not in KINDS:
            extra.append("kind '%s' unknown" % kind)
        base = theme.get("extends", "light")
        if base not in base_roles:
            extra.append("extends '%s' is not a base mode" % base)
            base = "light"
        face = theme.get("display")
        if face and face not in allowed_faces:
            extra.append(
                "display face '%s' is not in font.families.tenantDisplayFaces" % face
            )
        overrides = theme.get("roles", {})
        if not isinstance(overrides, dict):
            extra.append("roles must be an object")
            overrides = {}
        r = lint_theme(
            name,
            kind,
            base,
            base_roles[base],
            overrides,
            resolver,
            base_ratios[base],
            extra,
        )
        r["logo"] = theme.get("logo")
        r["display"] = face
        r["valid"] = theme.get("valid")
        results.append(r)

    themes = len(files)
    overridden = sum(len(r["overridden"]) for r in results)
    pairs = sum(len(r["contrast"]) for r in results)
    failures = sum(len(r["problems"]) for r in results)
    for r in results:
        print(
            "%s (extends %s, %s): %d roles overridden, %d pairs, %d failures"
            % (
                r["name"],
                r["extends"],
                r["kind"],
                len(r["overridden"]),
                len(r["contrast"]),
                len(r["problems"]),
            )
        )
        for p in r["problems"]:
            print("  - " + p)

    if args.preview:
        with open(args.template) as f:
            tpl = f.read()
        payload = {
            "product": tokens.get("meta", {}).get("name", ""),
            "font": tokens.get("font", {}).get("families", {}),
            "radius": tokens.get("radius", {}),
            "space": tokens.get("space", {}).get("scale", {}),
            "elevation": tokens.get("elevation", {}).get("levels", {}),
            "focus": tokens.get("focus", {}),
            "themes": [r for r in results if not r["name"].startswith("base:")]
            or results,
        }
        if "__THEMES_JSON__" not in tpl:
            print("theme-lint: template lacks __THEMES_JSON__", file=sys.stderr)
            sys.exit(1)
        with open(args.preview, "w") as f:
            f.write(
                tpl.replace(
                    "__THEMES_JSON__", json.dumps(payload).replace("</", "<\\/")
                )
            )
        print("preview: %s (%d themes)" % (args.preview, len(payload["themes"])))

    print(
        "theme-lint: %d themes, %d roles overridden, %d pairs checked, %d failures"
        % (themes, overridden, pairs, failures)
    )
    if themes == 0:
        print(
            "theme-lint: 0 themes under %s; themes writes light.json and dark.json first"
            % args.themes,
            file=sys.stderr,
        )
        sys.exit(1)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
