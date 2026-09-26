#!/usr/bin/env python3
"""system_page: the shared tokens.css and the visual design-system page, both
generated from tokens.json, and a gate that the page draws every component in
every state in both themes.

  system_page.py tokens-css [--tokens docs/design/tokens.json] [--out docs/design/tokens.css]
  system_page.py build [--tokens ...] [--components docs/design/components.md]
                       [--template <skill>/templates/design-system.html]
                       [--out docs/design/design-system.html]
  system_page.py check [--page docs/design/design-system.html]
                       [--components docs/design/components.md]

tokens-css writes one custom property per token (--color-<role>, --space-<n>,
--radius-<name>, --text-<role>, --duration-<name> ...) with the light roles on
:root and on any [data-theme="light"] element, the dark roles on any
[data-theme="dark"] element and under prefers-color-scheme, so a page can show
both themes side by side. Colours resolve through themes's theme-lint.py,
the kit's one colour calculator: hex first, oklch second.

build fills the template's foundations (every role swatch, type role, space,
radius, elevation and duration, read from tokens.json), draws each component's
specimens twice (a light pane and a dark pane) and cuts any component that
components.md does not list.

check reads each "## <Component>" entry and its "- States:" line in
components.md and requires a data-state="<state>" specimen inside that
component's section in the light pane and in the dark pane. It also fails on an
unfilled {{PLACEHOLDER}}, on a colour literal in a style block or attribute
(only tokens.css names colours), and on a page that neither links tokens.css
nor carries it inline. Prints the count line

  design-system: C components, S states, P specimens (light L, dark D), K missing, H hardcoded colours

and exits 1 on any problem or when zero components were checked.
"""

import argparse
import html
import importlib.util
import json
import os
import re
import sys
from html.parser import HTMLParser

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)
DEFAULT_LINT = os.path.join(SKILL, "..", "themes", "templates", "theme-lint.py")
DEFAULT_TEMPLATE = os.path.join(SKILL, "templates", "design-system.html")
VOID = {
    "area",
    "base",
    "br",
    "col",
    "embed",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "source",
    "track",
    "wbr",
}
COLOUR = re.compile(
    r"#[0-9a-fA-F]{3,8}\b|\b(?:rgba?|hsla?|oklch|oklab|lab|lch|color)\(", re.I
)


def load_theme_lint(path):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("theme_lint", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def read_tokens(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------- tokens-css


def colour_decls(tl, tokens, mode, problems):
    resolver = tl.Resolver(tokens, False)
    out = []
    for role, ref in sorted(tokens["color"]["roles"].get(mode, {}).items()):
        got = resolver.value(ref, "%s.%s" % (mode, role), problems)
        if got is None:
            continue
        _, hexv, ok, _ = got
        line = "--color-%s: %s;" % (role, hexv)
        if ok:
            line += " --color-%s: %s;" % (role, ok)
        out.append(line)
    return out


def static_decls(t):
    out = []
    fam = t.get("font", {}).get("families", {})
    for k in ("display", "body", "mono"):
        if k in fam:
            out.append("--font-%s: %s;" % (k, fam[k]))
    font = t.get("font", {})
    for role, r in sorted(font.get("roles", {}).items()):
        size = font.get("sizes", {}).get(r.get("size"), r.get("size"))
        out.append("--face-%s: var(--font-%s);" % (role, r.get("family", "body")))
        if isinstance(size, (int, float)):
            out.append("--text-%s: %spx;" % (role, size))
        w = font.get("weights", {}).get(r.get("weight"), r.get("weight"))
        if w is not None:
            out.append("--weight-%s: %s;" % (role, w))
        lh = font.get("lineHeights", {}).get(r.get("lineHeight"), r.get("lineHeight"))
        if lh is not None:
            out.append("--leading-%s: %s;" % (role, lh))
        tr = font.get("letterSpacing", {}).get(r.get("tracking"), r.get("tracking"))
        if tr is not None:
            out.append("--tracking-%s: %s;" % (role, tr))
    for k, v in sorted(
        t.get("space", {}).get("scale", {}).items(), key=lambda kv: kv[1]
    ):
        out.append("--space-%s: %spx;" % (k, v))
    for k, v in t.get("radius", {}).items():
        out.append("--radius-%s: %spx;" % (k, v))
    motion = t.get("motion", {})
    for k, v in motion.get("duration", {}).items():
        out.append("--duration-%s: %sms;" % (k, v))
    for k, v in motion.get("easing", {}).items():
        if isinstance(v, str):
            out.append("--ease-%s: %s;" % (k, v))
    for k, v in t.get("z", {}).items():
        out.append("--z-%s: %s;" % (k, v))
    for k, v in t.get("breakpoint", {}).items():
        out.append("--breakpoint-%s: %spx;" % (k, v))
    focus = t.get("focus", {})
    if "width" in focus:
        out.append("--focus-width: %spx;" % focus["width"])
    if "offset" in focus:
        out.append("--focus-offset: %spx;" % focus["offset"])
    return out


def elevation_decls(t, mode):
    out = []
    for k, v in sorted(t.get("elevation", {}).get("levels", {}).items()):
        if isinstance(v, dict) and mode in v:
            out.append("--elevation-%s: %s;" % (k, v[mode]))
    return out


def block(selector, decls, extra=""):
    body = "\n".join("  " + d for d in decls)
    return "%s {\n%s%s\n}\n" % (selector, body, ("\n  " + extra) if extra else "")


def tokens_css(args):
    tl = load_theme_lint(args.theme_lint)
    try:
        t = read_tokens(args.tokens)
        t["color"]["roles"]["light"]
    except (OSError, ValueError, KeyError, TypeError) as e:
        print(
            "tokens-css: cannot read roles from %s: %s" % (args.tokens, e),
            file=sys.stderr,
        )
        print("tokens-css: 0 custom properties, nothing written", file=sys.stderr)
        return 1
    problems = []
    light = colour_decls(tl, t, "light", problems)
    dark = colour_decls(tl, t, "dark", problems)
    static = static_decls(t)
    for p in problems:
        print("problem: %s" % p)
    if not light or not dark:
        print(
            "tokens-css: 0 colour roles in %s, nothing written"
            % ("light" if not light else "dark"),
            file=sys.stderr,
        )
        return 1
    version = t.get("meta", {}).get("version", "?")
    head = (
        "/* generated from docs/design/tokens.json v%s by system_page.py; do not edit.\n"
        "   The only file in the design bundle that names a colour. Screens and\n"
        "   design-system.html link it; a colour anywhere else is a defect. */\n"
        % version
    )
    css = head
    css += block(
        ':root, [data-theme="light"]',
        static + light + elevation_decls(t, "light"),
        "color-scheme: light;",
    )
    css += block(
        '[data-theme="dark"]', dark + elevation_decls(t, "dark"), "color-scheme: dark;"
    )
    css += (
        "@media (prefers-color-scheme: dark) {\n"
        + block(
            ':root:not([data-theme="light"])',
            dark + elevation_decls(t, "dark"),
            "color-scheme: dark;",
        )
        + "}\n"
    )
    css += (
        ":focus-visible { outline: var(--focus-width, 2px) solid var(--color-focus);"
        " outline-offset: var(--focus-offset, 2px); }\n"
    )
    durs = ["--duration-%s: 0ms;" % k for k in t.get("motion", {}).get("duration", {})]
    if durs:
        css += (
            "@media (prefers-reduced-motion: reduce) {\n" + block(":root", durs) + "}\n"
        )
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(css)
    n = len(static) + len(light) + len(dark)
    print(
        "tokens-css: %d custom properties (colour roles light %d, dark %d), %d problems, wrote %s"
        % (n, len(light), len(dark), len(problems), args.out)
    )
    return 1 if problems else 0


# ---------------------------------------------------------------- components.md


def contract(path):
    """[(component, [states])] from '## Name' entries and their '- States:' line."""
    out = []
    text = open(path, encoding="utf-8").read()
    text = re.sub(r"^```.*?^```", "", text, flags=re.M | re.S)
    for m in re.finditer(r"^## (.+?)\s*$(.*?)(?=^## |\Z)", text, re.M | re.S):
        name, body = m.group(1).strip(), m.group(2)
        s = re.search(r"^- States:\s*(.+)$", body, re.M)
        if not s:
            continue
        states = [
            x.strip().strip("`.").lower()
            for x in s.group(1).rstrip(".").split(",")
            if x.strip().strip("`.")
        ]
        out.append((name, states))
    return out


# ---------------------------------------------------------------- build


def swatch_rows(t):
    rows = []
    light = t["color"]["roles"].get("light", {})
    dark = t["color"]["roles"].get("dark", {})
    for role in sorted(set(light) | set(dark)):

        def show(v):
            if isinstance(v, dict):
                return v.get("oklch", "")
            return str(v)

        rows.append(
            '<tr><th scope="row"><code>--color-%s</code></th>'
            '<td data-theme="light"><span class="sw" style="background: var(--color-%s)"></span>'
            "<code>%s</code></td>"
            '<td data-theme="dark"><span class="sw" style="background: var(--color-%s)"></span>'
            "<code>%s</code></td></tr>"
            % (
                role,
                role,
                html.escape(show(light.get(role, ""))),
                role,
                html.escape(show(dark.get(role, ""))),
            )
        )
    return rows


def foundations(t):
    parts = [
        "<h3>Colour roles, light and dark</h3>",
        '<div class="table-wrap"><table class="roles"><thead><tr><th>Role</th>'
        "<th>Light</th><th>Dark</th></tr></thead><tbody>",
    ]
    parts += swatch_rows(t)
    parts.append("</tbody></table></div>")
    font = t.get("font", {})
    if font.get("roles"):
        parts.append('<h3>Type roles</h3><div class="type-roles">')
        for role in font["roles"]:
            parts.append(
                '<p class="type-row"><code>%s</code><span style="font-family: var(--face-%s);'
                " font-size: var(--text-%s); font-weight: var(--weight-%s);"
                ' line-height: var(--leading-%s); letter-spacing: var(--tracking-%s)">'
                "The quick decision reads first</span></p>" % ((role,) * 6)
            )
        parts.append("</div>")
    scale = t.get("space", {}).get("scale", {})
    if scale:
        parts.append('<h3>Space</h3><div class="space-rows">')
        for k, v in sorted(scale.items(), key=lambda kv: kv[1]):
            parts.append(
                '<p class="space-row"><code>--space-%s</code><span class="bar" '
                'style="inline-size: var(--space-%s)"></span><span>%spx</span></p>'
                % (k, k, v)
            )
        parts.append("</div>")
    if t.get("radius"):
        parts.append('<h3>Radius</h3><div class="tiles">')
        for k in t["radius"]:
            parts.append(
                '<div class="tile" style="border-radius: var(--radius-%s)"><code>--radius-%s</code></div>'
                % (k, k)
            )
        parts.append("</div>")
    levels = t.get("elevation", {}).get("levels", {})
    if levels:
        parts.append('<h3>Elevation</h3><div class="tiles">')
        for k in sorted(levels):
            parts.append(
                '<div class="tile" style="box-shadow: var(--elevation-%s)"><code>--elevation-%s</code></div>'
                % (k, k)
            )
        parts.append("</div>")
        rule = t.get("elevation", {}).get("rule")
        if rule:
            parts.append('<p class="rule">%s</p>' % html.escape(rule))
    durs = t.get("motion", {}).get("duration", {})
    if durs:
        parts.append('<h3>Motion</h3><ul class="durations">')
        for k, v in durs.items():
            parts.append("<li><code>--duration-%s</code> %sms</li>" % (k, v))
        parts.append("</ul>")
    return "\n".join(parts)


SPEC = re.compile(
    r'<div class="specimens" data-specimens>(.*?)</div><!-- /specimens -->', re.S
)
SECTION = re.compile(
    r'(<section class="component" data-component="([^"]+)".*?</section><!-- /component -->)\s*',
    re.S,
)


def build(args):
    try:
        t = read_tokens(args.tokens)
        t["color"]["roles"]["light"]
    except (OSError, ValueError, KeyError, TypeError) as e:
        print("build: cannot read %s: %s" % (args.tokens, e), file=sys.stderr)
        return 1
    page = open(args.template, encoding="utf-8").read()
    kept, cut = [], []
    if args.components and os.path.isfile(args.components):
        names = {n for n, _ in contract(args.components)}

        def keep(m):
            if m.group(2) in names:
                kept.append(m.group(2))
                return m.group(0)
            cut.append(m.group(2))
            return ""

        page = SECTION.sub(keep, page)
    else:
        kept = [m.group(2) for m in SECTION.finditer(page)]
    page = SPEC.sub(
        lambda m: '<div class="panes"><div class="pane" data-theme="light">'
        '<p class="pane-label">Light</p><div class="specimens">%s</div></div>'
        '<div class="pane" data-theme="dark"><p class="pane-label">Dark</p>'
        '<div class="specimens">%s</div></div></div>' % (m.group(1), m.group(1)),
        page,
    )
    meta = t.get("meta", {})
    page = (
        page.replace("{{PRODUCT}}", html.escape(str(meta.get("name", "Product"))))
        .replace("{{VERSION}}", str(meta.get("version", "?")))
        .replace("{{SOURCE}}", html.escape(str(meta.get("source", "?"))))
        .replace("{{MEMORABLE}}", html.escape(str(meta.get("memorable", ""))))
        .replace("{{FOUNDATIONS}}", foundations(t))
    )
    faces = []
    for fam in (t.get("font", {}).get("families", {}) or {}).values():
        m = re.match(r'\s*"([^"]+)"', str(fam))
        if m and m.group(1) not in faces:
            faces.append(m.group(1))
    fonts = (
        '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?%s&display=swap">'
        % "&".join("family=" + f.replace(" ", "+") for f in faces)
        if faces
        else ""
    )
    page = page.replace("{{FONTS_LINK}}", fonts)
    toc = "\n".join(
        '<a href="#c-%s">%s</a>'
        % (re.sub(r"[^a-z0-9]+", "-", n.lower()).strip("-"), html.escape(n))
        for n in kept
    )
    page = page.replace("{{TOC}}", toc)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(page)
    print(
        "build: %d components drawn in light and dark, %d cut (%s), wrote %s"
        % (len(kept), len(cut), ", ".join(cut) or "none", args.out)
    )
    return 0


# ---------------------------------------------------------------- check


class Specimens(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.found = set()  # (component, theme, state)
        self.style_attrs = []
        self.links = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if a.get("style"):
            self.style_attrs.append(a["style"])
        if tag == "link" and "stylesheet" in (a.get("rel") or ""):
            self.links.append(a.get("href", ""))
        if tag in VOID:
            self._record(a)
            return
        self.stack.append((tag, a))
        self._record(a)

    def handle_startendtag(self, tag, attrs):
        a = dict(attrs)
        if a.get("style"):
            self.style_attrs.append(a["style"])
        self._record(a)

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                return

    def _record(self, a):
        state = a.get("data-state")
        if not state:
            return
        comp = theme = None
        for _, anc in reversed(self.stack):
            if theme is None and anc.get("data-theme"):
                theme = anc["data-theme"]
            if comp is None and anc.get("data-component"):
                comp = anc["data-component"]
        if comp and theme:
            self.found.add((comp, theme, state.lower()))


def colour_literals(page, attrs):
    hits = []
    for css in re.findall(r"<style[^>]*>(.*?)</style>", page, re.S | re.I):
        css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
        hits += COLOUR.findall(css)
    for s in attrs:
        hits += COLOUR.findall(s)
    return hits


def check(args):
    if not os.path.isfile(args.page):
        print(
            "design-system: %s not found, 0 components checked" % args.page,
            file=sys.stderr,
        )
        return 1
    if not os.path.isfile(args.components):
        print(
            "design-system: %s not found, 0 components checked" % args.components,
            file=sys.stderr,
        )
        return 1
    want = contract(args.components)
    if not want:
        print(
            'design-system: 0 components with a "- States:" line in %s, nothing checked'
            % args.components,
            file=sys.stderr,
        )
        return 1
    page = open(args.page, encoding="utf-8").read()
    p = Specimens()
    p.feed(page)
    problems = []
    n_states = 0
    per_theme = {"light": 0, "dark": 0}
    for comp, theme, _ in p.found:
        if theme in per_theme:
            per_theme[theme] += 1
    for comp, states in want:
        for s in states:
            n_states += 1
            for theme in ("light", "dark"):
                if (comp, theme, s) not in p.found:
                    problems.append(
                        '%s: no data-state="%s" specimen in the %s pane'
                        % (comp, s, theme)
                    )
    missing = len(problems)
    holes = sorted(set(re.findall(r"\{\{[A-Z_#/]+\}\}", page)))
    if holes:
        problems.append("unfilled placeholders %s" % ", ".join(holes[:5]))
    base = os.path.dirname(os.path.abspath(args.page))
    linked = [h for h in p.links if h.split("?")[0].endswith("tokens.css")]
    inline = re.search(r"<style[^>]*\bdata-tokens\b", page) is not None
    if not inline:
        if not linked:
            problems.append(
                "page neither links tokens.css nor carries it inline (<style data-tokens>)"
            )
        for h in linked:
            if not os.path.isfile(os.path.join(base, h.split("?")[0])):
                problems.append("tokens.css link %s points at no file" % h)
    tokens_block = re.sub(
        r"<style[^>]*\bdata-tokens\b[^>]*>.*?</style>", "", page, flags=re.S
    )
    hard = colour_literals(tokens_block, p.style_attrs)
    if hard:
        problems.append(
            "%d colour literals outside tokens.css (first: %s)"
            % (len(hard), ", ".join(hard[:3]))
        )
    for pr in problems:
        print("problem: %s" % pr)
    print(
        "design-system: %d components, %d states, %d specimens (light %d, dark %d), "
        "%d missing, %d hardcoded colours"
        % (
            len(want),
            n_states,
            per_theme["light"] + per_theme["dark"],
            per_theme["light"],
            per_theme["dark"],
            missing,
            len(hard),
        )
    )
    return 1 if problems else 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("tokens-css")
    a.add_argument("--tokens", default="docs/design/tokens.json")
    a.add_argument("--out", default="docs/design/tokens.css")
    a.add_argument("--theme-lint", default=DEFAULT_LINT)
    b = sub.add_parser("build")
    b.add_argument("--tokens", default="docs/design/tokens.json")
    b.add_argument("--components", default="docs/design/components.md")
    b.add_argument("--template", default=DEFAULT_TEMPLATE)
    b.add_argument("--out", default="docs/design/design-system.html")
    c = sub.add_parser("check")
    c.add_argument("--page", default="docs/design/design-system.html")
    c.add_argument("--components", default="docs/design/components.md")
    args = ap.parse_args()
    if args.cmd == "tokens-css":
        if not os.path.isfile(args.theme_lint):
            print(
                "tokens-css: theme-lint.py not found at %s" % args.theme_lint,
                file=sys.stderr,
            )
            return 1
        return tokens_css(args)
    if args.cmd == "build":
        return build(args)
    return check(args)


if __name__ == "__main__":
    sys.exit(main())
