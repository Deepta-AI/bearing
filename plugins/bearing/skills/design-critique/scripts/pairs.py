#!/usr/bin/env python3
"""pairs: compute every text and control colour pair of static HTML pages in
light and in both dark paths, from the CSS the pages actually load, so the
contrast findings of a design review are measured, not eyeballed.

  pairs.py [--need 4.5] <page.html>...
  pairs.py ratio <fg> <bg>...     one colour on each background (hex, rgb,
                                  hsl or oklch), for a colour typed by hand

For each page it reads the linked local stylesheets and the inline <style>,
builds the cascade for every element (custom properties inherit, var()
resolves, background comes from the nearest painted ancestor, alpha is
composited) in three contexts:
  light        no data-theme, prefers-color-scheme light
  dark-attr    <html data-theme="dark">, system light
  dark-media   no data-theme, prefers-color-scheme dark
and prints:
  FAIL lines   text below 4.5:1 (3:1 at 24 px, or 18.66 px bold) and field
               edges (input, select, textarea: border or fill) below 3:1
               against what surrounds them (WCAG 1.4.11), with file:line,
               element, text, colours, ratio and the context(s);
               a raw colour in a page rule shows up here in the theme it breaks
  focus        rings from :focus and :focus-visible rules, measured at 3:1
               against the surface they are drawn on (the parent's
               background: the same button can pass on the page and fail on
               a panel), and outline removed with nothing in its place
  fix lines    for each failing text colour, the nearest colour of the same
               hue (oklch lightness only) that passes on EVERY background
               that colour sits on in that context; when the colour passes
               on some backgrounds, the background is named as the fault;
               for text on a filled control, the fill that would pass instead
  parity       a custom property the data-theme dark block sets and the
               prefers-color-scheme dark block does not, or the reverse
  raw          colour literals written in a page's own <style> or style=""
  font         a family the pages ask for that no @font-face or font
               stylesheet link loads (it renders as the fallback, unless
               the viewer has it installed)
and one counts line. Exits 1 on any FAIL or parity gap, and when zero pages
or zero text pairs were checked. Rules under other @media queries and rules
with other state pseudo-classes (:hover, :active...) are counted as skipped,
never guessed; judge those states from the source.
"""

import colorsys
import math
import os
import re
import sys
import urllib.parse
from html.parser import HTMLParser

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
CONTROLS = {"input", "select", "textarea", "button"}
FIELDS = {"input", "select", "textarea"}
HIDDEN_TYPES = {"hidden", "submit", "button", "checkbox", "radio"}
NAMED = {
    "white": "#ffffff",
    "black": "#000000",
    "transparent": "rgba(0,0,0,0)",
    "red": "#ff0000",
    "gray": "#808080",
    "grey": "#808080",
    "canvas": None,
    "currentcolor": None,
}
GENERIC = {
    "serif",
    "sans-serif",
    "monospace",
    "system-ui",
    "ui-sans-serif",
    "ui-monospace",
    "ui-serif",
    "cursive",
    "fantasy",
    "-apple-system",
    "blinkmacsystemfont",
    "inherit",
    "initial",
}
CONTEXTS = ("light", "dark-attr", "dark-media")
COLOUR_RE = re.compile(r"#[0-9a-fA-F]{3,8}\b|\b(?:rgba?|hsla?|oklch)\([^)]*\)")


# ---------- colour maths ----------


def parse_colour(v):
    """(r, g, b, a) floats 0..1, or None."""
    if v is None:
        return None
    v = v.strip().lower()
    if v in NAMED:
        v = NAMED[v]
        if v is None:
            return None
    m = re.fullmatch(r"#([0-9a-f]{3,8})", v)
    if m:
        h = m.group(1)
        if len(h) in (3, 4):
            h = "".join(c * 2 for c in h)
        if len(h) not in (6, 8):
            return None
        r, g, b = (int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))
        a = int(h[6:8], 16) / 255 if len(h) == 8 else 1.0
        return (r, g, b, a)
    m = re.fullmatch(r"(rgba?|oklch|hsla?)\((.*)\)", v)
    if not m:
        return None
    parts = [p for p in re.split(r"[\s,/]+", m.group(2).strip()) if p]

    def num(p, scale):
        return float(p[:-1]) / 100 * scale if p.endswith("%") else float(p)

    try:
        if m.group(1).startswith("rgb"):
            r, g, b = (num(p, 255) / 255 for p in parts[:3])
            a = num(parts[3], 1) if len(parts) > 3 else 1.0
            return (r, g, b, a)
        if m.group(1).startswith("hsl"):
            h = float(parts[0].replace("deg", "")) / 360
            s, li = num(parts[1], 1), num(parts[2], 1)
            r, g, b = colorsys.hls_to_rgb(h, li, s)
            a = num(parts[3], 1) if len(parts) > 3 else 1.0
            return (r, g, b, a)
        L = num(parts[0], 1)
        C = num(parts[1], 0.4)
        H = float(parts[2].replace("deg", "")) if parts[2] != "none" else 0.0
        a = num(parts[3], 1) if len(parts) > 3 else 1.0
        r, g, b = oklch_to_srgb(L, C, H)
        return (r, g, b, a)
    except (ValueError, IndexError):
        return None


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def delin(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def oklch_to_srgb(L, C, H):
    a, b = C * math.cos(math.radians(H)), C * math.sin(math.radians(H))
    l_ = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m_ = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s_ = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    r = 4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_
    g = -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_
    bl = -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_
    return delin(r), delin(g), delin(bl)


def srgb_to_oklch(r, g, b):
    r, g, b = lin(r), lin(g), lin(b)
    l_ = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m_ = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s_ = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    return L, math.hypot(a, bb), math.degrees(math.atan2(bb, a)) % 360


def over(fg, bg):
    a = fg[3]
    return tuple(fg[i] * a + bg[i] * (1 - a) for i in range(3)) + (1.0,)


def lum(c):
    return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])


def ratio(x, y):
    a, b = sorted((lum(x), lum(y)), reverse=True)
    return (a + 0.05) / (b + 0.05)


def hexof(c):
    return "#" + "".join(f"{round(max(0, min(1, v)) * 255):02x}" for v in c[:3])


def suggest(fg, bgs, need):
    """Nearest same-hue colour (oklch L only) passing on every bg, or None."""
    L, C, H = srgb_to_oklch(*fg[:3])
    best = None
    for direction in (-1, 1):
        for step in range(1, 201):
            L2 = L + direction * step * 0.005
            if not 0 <= L2 <= 1:
                break
            cand = oklch_to_srgb(L2, C, H) + (1.0,)
            if all(ratio(cand, b) >= need for b in bgs):
                if best is None or step < best[0]:
                    best = (step, cand)
                break
    return hexof(best[1]) if best else None


# ---------- CSS ----------


def strip_comments(css):
    return re.sub(r"/\*.*?\*/", "", css, flags=re.S)


def blocks(css, media=None, out=None, src="", fonts=None):
    """Flatten css into (selector, decls, media, src) rules; collect @font-face."""
    out = [] if out is None else out
    i, n = 0, len(css)
    while i < n:
        j = css.find("{", i)
        if j < 0:
            break
        head = css[i:j].strip()
        depth, k = 1, j + 1
        while k < n and depth:
            depth += {"{": 1, "}": -1}.get(css[k], 0)
            k += 1
        body = css[j + 1 : k - 1]
        if head.startswith("@media"):
            blocks(body, head[6:].strip(), out, src, fonts)
        elif head.startswith("@font-face"):
            m = re.search(r"font-family\s*:\s*([^;]+)", body)
            if m and fonts is not None:
                fonts.add(m.group(1).strip().strip("'\"").lower())
        elif head.startswith("@"):
            pass
        else:
            out.append((head, decls(body), media, src))
        i = k
    return out


def decls(body):
    d = []
    for part in body.split(";"):
        if ":" in part:
            k, v = part.split(":", 1)
            d.append((k.strip().lower(), v.strip()))
    return d


def media_ok(media, ctx):
    if media is None:
        return True
    m = media.replace(" ", "").lower()
    if m == "(prefers-color-scheme:dark)":
        return ctx == "dark-media"
    if m == "(prefers-color-scheme:light)":
        return ctx != "dark-media"
    return None  # another query: skipped, counted


# ---------- selectors ----------

SIMPLE = re.compile(
    r"(\*|[a-zA-Z][\w-]*)|#([\w-]+)|\.([\w-]+)|\[([\w-]+)(?:=[\"']?([^\"'\]]*)[\"']?)?\]"
    r"|:not\(([^)]*)\)|::?([\w-]+)"
)
STATE = {
    "hover",
    "focus",
    "focus-visible",
    "focus-within",
    "active",
    "visited",
    "disabled",
    "checked",
    "invalid",
    "placeholder",
    "before",
    "after",
    "selection",
    "target",
    "link",
    "placeholder-shown",
}


def compound(s):
    """List of tests, or None when the compound has a state pseudo."""
    tests, pos = [], 0
    for m in SIMPLE.finditer(s):
        if m.start() != pos:
            return "bad"
        pos = m.end()
        tag, idv, cls, attr, aval, notv, pseudo = m.groups()
        if tag:
            tests.append(("tag", tag.lower()))
        elif idv:
            tests.append(("id", idv))
        elif cls:
            tests.append(("class", cls))
        elif attr:
            tests.append(("attr", attr, aval))
        elif notv is not None:
            inner = compound(notv.strip())
            if inner in ("bad", None):
                return inner
            tests.append(("not", inner))
        elif pseudo in STATE:
            return None
        elif pseudo == "root":
            tests.append(("tag", "html"))
        elif pseudo in ("first-child", "last-child"):
            tests.append((pseudo,))
        else:
            return "bad"
    return tests if pos == len(s) else "bad"


def match_compound(tests, el):
    for t in tests:
        kind = t[0]
        if kind == "tag" and t[1] != "*" and el.tag != t[1]:
            return False
        if kind == "id" and el.attrs.get("id") != t[1]:
            return False
        if kind == "class" and t[1] not in el.attrs.get("class", "").split():
            return False
        if kind == "attr":
            if t[1] not in el.attrs or (t[2] is not None and el.attrs[t[1]] != t[2]):
                return False
        if kind == "not" and match_compound(t[1], el):
            return False
        if kind in ("first-child", "last-child"):
            sib = [c for c in el.parent.children] if el.parent else [el]
            if sib[0 if kind == "first-child" else -1] is not el:
                return False
    return True


def parse_selector(sel):
    parts = re.split(r"\s*(>)\s*|\s+", sel.strip())
    parts = [p for p in parts if p]
    seq, comb = [], " "
    for p in parts:
        if p == ">":
            comb = ">"
            continue
        c = compound(p)
        if c in ("bad", None):
            return c
        seq.append((comb, c))
        comb = " "
    return seq


def match(seq, el):
    def rec(i, node):
        comb, tests = seq[i]
        if not match_compound(tests, node):
            return False
        if i == 0:
            return True
        up = node.parent
        if comb == ">":
            return up is not None and rec(i - 1, up)
        while up is not None:
            if rec(i - 1, up):
                return True
            up = up.parent
        return False

    return rec(len(seq) - 1, el)


def specificity(seq):
    a = b = c = 0
    for _, tests in seq:
        for t in tests:
            if t[0] == "id":
                a += 1
            elif t[0] in ("class", "attr", "first-child", "last-child", "not"):
                b += 1
            elif t[0] == "tag" and t[1] != "*":
                c += 1
    return (a, b, c)


# ---------- DOM ----------


class El:
    def __init__(self, tag, attrs, parent, line):
        self.tag, self.attrs, self.parent, self.line = tag, attrs, parent, line
        self.children, self.text = [], ""


class Doc(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = El("#doc", {}, None, 0)
        self.cur = self.root
        self.sheets, self.styles, self.font_links = [], [], []
        self.in_style = False

    def handle_starttag(self, tag, attrs):
        a = {k: (v or "") for k, v in attrs}
        el = El(tag, a, self.cur if self.cur.tag != "#doc" else None, self.getpos()[0])
        self.cur.children.append(el)
        if tag == "link" and "stylesheet" in a.get("rel", ""):
            href = a.get("href", "")
            if href.startswith(("http://", "https://", "//")):
                self.font_links.append(href)
            else:
                self.sheets.append(href)
        if tag == "style":
            self.in_style = True
            self.styles.append(("", self.getpos()[0]))
        if tag not in VOID:
            self.cur = el

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in VOID:
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        node = self.cur
        while node is not None and node is not self.root and node.tag != tag:
            node = node.parent
        if node is not None and node is not self.root:
            self.cur = node.parent or self.root
        if tag == "style":
            self.in_style = False

    def handle_data(self, data):
        if self.in_style:
            css, line = self.styles[-1]
            self.styles[-1] = (css + data, line)
        elif self.cur is not self.root:
            self.cur.text += data


def walk(el):
    yield el
    for c in el.children:
        yield from walk(c)


# ---------- cascade ----------


def resolve(v, props, depth=0):
    if v is None or depth > 10:
        return v

    def sub(m):
        name, fb = m.group(1).strip(), m.group(2)
        got = props.get(name)
        if got is None and fb is not None:
            got = fb.strip()
        return resolve(got, props, depth + 1) if got is not None else "UNRESOLVED"

    return re.sub(
        r"var\(\s*(--[\w-]+)\s*(?:,\s*([^()]*(?:\([^()]*\))?[^()]*))?\)", sub, v
    )


def first_colour(v):
    if v is None:
        return None
    m = COLOUR_RE.search(v)
    if m:
        return m.group(0)
    for w in re.split(r"\s+", v.strip().lower()):
        if w in NAMED:
            return w
    return None


def px(v, parent):
    m = re.fullmatch(r"([\d.]+)(px|rem|em|%)?", v.strip())
    if not m:
        return parent
    n, unit = float(m.group(1)), m.group(2) or "px"
    return {"px": n, "rem": n * 16, "em": n * parent, "%": n / 100 * parent}[unit]


def dark_scheme(cs, ctx):
    """Does the browser paint its canvas and form controls dark? Only when
    color-scheme allows dark and the system asks for it, or it allows dark
    only; data-theme alone never changes the used scheme."""
    cs = cs.lower()
    return "dark" in cs and (ctx == "dark-media" or "light" not in cs)


FOCUS_RE = re.compile(r":focus(?:-visible)?(?![\w-])")


def focus_selector(one):
    """The selector of a :focus or :focus-visible rule with the pseudo
    removed, when that is its only state; else None."""
    if not FOCUS_RE.search(one):
        return None
    seq = parse_selector(FOCUS_RE.sub("", one))
    return seq if seq not in (None, "bad") and seq else None


def focusable(el):
    return (
        el.tag in CONTROLS
        or (el.tag == "a" and "href" in el.attrs)
        or "tabindex" in el.attrs
    ) and el.attrs.get("type") != "hidden"


def ring_of(el, decl, focus_live, props, colour):
    """What focus draws on a focusable element: None (no focus rule, the
    browser default ring), "removed" (outline none and no box-shadow), or
    the ring colour."""
    if not focusable(el):
        return None
    fd = {}
    for _, _, seq, ds in focus_live:
        if match(seq, el):
            for k, v in ds:
                fd[k] = v
    if not fd:
        return None
    g = lambda k: resolve(fd.get(k), props)  # noqa: E731
    outline = (g("outline") or "").lower()
    style = (g("outline-style") or "").lower()
    shadow = (g("box-shadow") or "").lower()
    col = first_colour(g("outline-color") or "") or first_colour(outline)
    shadow_col = first_colour(shadow) if shadow and shadow != "none" else None
    gone = re.search(r"(^|\s)(none|0)(\s|$)", outline) or style == "none"
    if col and not gone:
        return col
    if shadow_col:
        return shadow_col
    if gone:
        return "removed"
    if outline or style:
        return colour  # an outline with no colour is drawn in currentColor
    return None


def compute(doc, rules, ctx, stats):
    html = next((e for e in walk(doc.root) if e.tag == "html"), None)
    if html is None:
        return {}
    saved = dict(html.attrs)
    if ctx == "dark-attr":
        html.attrs["data-theme"] = "dark"
    else:
        html.attrs.pop("data-theme", None)
    live, focus_live = [], []
    for order, (sel, ds, media, src) in enumerate(rules):
        ok = media_ok(media, ctx)
        if ok is None:
            stats["skipped_media"] += 1
            continue
        if not ok:
            continue
        for one in sel.split(","):
            seq = parse_selector(one)
            if seq is None:
                ring = focus_selector(one)
                if ring:
                    focus_live.append((specificity(ring), order, ring, ds))
                else:
                    stats["skipped_state"] += 1
                continue
            if seq == "bad" or not seq:
                stats["skipped_other"] += 1
                continue
            live.append((specificity(seq), order, seq, ds))
    live.sort(key=lambda r: (r[0], r[1]))
    focus_live.sort(key=lambda r: (r[0], r[1]))
    out = {}

    def visit(el, inh):
        decl = {}
        for _, _, seq, ds in live:
            if match(seq, el):
                for k, v in ds:
                    decl[k] = v
        for k, v in decls(el.attrs.get("style", "")):
            decl[k] = v
        props = dict(inh["props"])
        props.update({k: v for k, v in decl.items() if k.startswith("--")})
        g = lambda k: resolve(decl.get(k), props)  # noqa: E731
        font = g("font")
        size, weight, family = inh["size"], inh["weight"], inh["family"]
        if font:
            m = re.search(
                r"(?:(\d{3}|bold|normal)\s+)?([\d.]+(?:px|rem|em|%))(?:/\S+)?\s+(.+)",
                font,
            )
            if m:
                weight = {"bold": 700, "normal": 400}.get(
                    m.group(1), int(m.group(1)) if m.group(1) else 400
                )
                size, family = px(m.group(2), inh["size"]), m.group(3)
        if g("font-size"):
            size = px(g("font-size"), inh["size"])
        if g("font-weight"):
            w = g("font-weight")
            weight = {"bold": 700, "normal": 400}.get(
                w, int(w) if w.isdigit() else weight
            )
        if g("font-family"):
            family = g("font-family")
        colour = first_colour(g("color")) or inh["colour"]
        if el.tag in CONTROLS and not g("color"):
            colour = "#ffffff" if inh["dark_canvas"] else "#000000"
        bgv = first_colour(g("background-color") or g("background"))
        if el.tag in ("input", "select", "textarea") and bgv is None:
            bgv = "#ffffff" if ctx == "light" or not inh["dark_canvas"] else "#3b3b3b"
        if el.tag == "button" and bgv is None:
            bgv = "#efefef" if ctx == "light" or not inh["dark_canvas"] else "#6b6b6b"
        bg = inh["bg"]
        own = parse_colour(bgv) if bgv else None
        if own and own[3] > 0:
            bg = over(own, bg)
        border = None
        bw = g("border") or g("border-width") or ""
        if (
            el.tag in CONTROLS
            and not re.search(r"(^|\s)(0|none)(\s|$)", bw)
            and (g("border") or g("border-color"))
        ):
            border = first_colour(g("border-color") or g("border"))
        cs = g("color-scheme")
        dark_canvas = inh["dark_canvas"] if cs is None else dark_scheme(cs, ctx)
        state = {
            "props": props,
            "size": size,
            "weight": weight,
            "family": family,
            "colour": colour,
            "bg": bg,
            "dark_canvas": dark_canvas,
        }
        out[id(el)] = {
            "el": el,
            "colour": colour,
            "bg": bg,
            "outside": inh["bg"],
            "own_bg": own,
            "border": border,
            "size": size,
            "weight": weight,
            "family": family,
            "raw_decl": {k: v for k, v in decl.items() if not k.startswith("--")},
            "ring": ring_of(el, decl, focus_live, props, colour),
        }
        for c in el.children:
            visit(c, state)

    # the canvas follows color-scheme on the root
    base = {
        "props": {},
        "size": 16.0,
        "weight": 400,
        "family": "serif",
        "colour": "#000000",
        "bg": (1.0, 1.0, 1.0, 1.0),
        "dark_canvas": False,
    }
    # first pass for :root's color-scheme and background
    visit(html, base)
    root = out[id(html)]
    scheme = resolve(dict(root["raw_decl"]).get("color-scheme"), {}) or ""
    if dark_scheme(scheme, ctx):
        dark = {
            **base,
            "bg": (0x12 / 255, 0x12 / 255, 0x12 / 255, 1.0),
            "colour": "#ffffff",
            "dark_canvas": True,
        }
        out.clear()
        visit(html, dark)
    html.attrs.clear()
    html.attrs.update(saved)
    return out


# ---------- report ----------


def ratio_cmd(argv):
    """ratio <fg> <bg>...: the contrast of one colour on each background,
    for a colour typed by hand into a finding or a fix."""
    cols = [(a, parse_colour(a)) for a in argv]
    bad = [a for a, c in cols if c is None]
    if len(cols) < 2 or bad:
        print(
            "design-pairs: ratio needs a colour and at least one background"
            + (f"; not a colour: {', '.join(bad)}" if bad else ""),
            file=sys.stderr,
        )
        return 1
    (fa, fg), bgs = cols[0], cols[1:]
    for ba, bg in bgs:
        c = over(fg, over(bg, (1.0, 1.0, 1.0, 1.0)))
        q = ratio(c, over(bg, (1.0, 1.0, 1.0, 1.0)))
        verdict = ", ".join(
            f"{'passes' if q >= n else 'fails'} {n:g}" for n in (4.5, 3.0)
        )
        print(f"ratio: {fa} on {ba} = {q:.2f}:1 ({verdict})")
    print(f"design-pairs: ratio of 1 colour on {len(bgs)} backgrounds")
    return 0


def main(argv):
    if argv[:1] == ["ratio"]:
        return ratio_cmd(argv[1:])
    need_body = 4.5
    if argv[:1] == ["--need"]:
        need_body, argv = float(argv[1]), argv[2:]
    pages = [p for p in argv if p.endswith((".html", ".htm"))]
    if not pages:
        print("design-pairs: 0 pages given, nothing checked", file=sys.stderr)
        return 1
    stats = {"skipped_media": 0, "skipped_state": 0, "skipped_other": 0}
    fails, parity, raws, fonts_used, fonts_loaded = {}, set(), [], {}, set()
    text_pairs = control_pairs = 0
    per_fg = {}
    ring_bgs, rings_removed, ring_count = {}, set(), [0]
    seen_sheets = set()
    for page in pages:
        d = Doc()
        d.feed(open(page, encoding="utf-8").read())
        folder = os.path.dirname(page)
        rules = []
        for href in d.sheets:
            path = os.path.normpath(os.path.join(folder, href))
            if not os.path.isfile(path):
                continue
            css = strip_comments(open(path, encoding="utf-8").read())
            rs = blocks(css, src=path, fonts=fonts_loaded)
            rules += rs
            if path not in seen_sheets:
                seen_sheets.add(path)
                attr, med = set(), set()
                for sel, ds, media, _ in rs:
                    names = {k for k, _ in ds if k.startswith("--")}
                    if media and "dark" in media and "prefers-color-scheme" in media:
                        med |= names
                    elif (
                        'data-theme="dark"' in sel
                        or "data-theme='dark'" in sel
                        or "data-theme=dark" in sel
                    ):
                        attr |= names
                for n in sorted(attr - med):
                    parity.add(
                        f"{path}: {n} is set for data-theme dark but not under prefers-color-scheme dark"
                    )
                for n in sorted(med - attr):
                    parity.add(
                        f"{path}: {n} is set under prefers-color-scheme dark but not for data-theme dark"
                    )
        for css, line in d.styles:
            css = strip_comments(css)
            rules += blocks(css, src=page, fonts=fonts_loaded)
            for i, row in enumerate(css.split("\n")):
                for m in COLOUR_RE.finditer(row):
                    raws.append(
                        f"{page}:{line + i}: {m.group(0)} in `{row.strip()[:70]}`"
                    )
        for href in d.font_links:
            q = urllib.parse.parse_qs(urllib.parse.urlparse(href).query)
            for fam in q.get("family", []):
                fonts_loaded.add(fam.split(":")[0].replace("+", " ").lower())
        for el in walk(d.root):
            if "style" in el.attrs:
                for m in COLOUR_RE.finditer(el.attrs["style"]):
                    raws.append(f'{page}:{el.line}: {m.group(0)} in style=""')
        results = {}
        for ctx in CONTEXTS:
            for key, r in compute(d, rules, ctx, stats).items():
                results.setdefault(key, {})[ctx] = r
        for key, per in results.items():
            el = per["light"]["el"]
            text = re.sub(r"\s+", " ", el.text).strip()
            if el.tag == "input":
                text = el.attrs.get("value") or el.attrs.get("placeholder") or ""
            if el.tag in ("html", "head", "style", "title", "script", "meta", "link"):
                continue
            fam = (
                (per["light"]["family"] or "")
                .split(",")[0]
                .strip()
                .strip("'\"")
                .lower()
            )
            if text and fam and fam not in GENERIC:
                fonts_used.setdefault(fam, set()).add(os.path.basename(page))
            where = f"{page}:{el.line} <{el.tag}{'.' + '.'.join(el.attrs['class'].split()) if el.attrs.get('class') else ''}>"
            if text:
                text_pairs += 1
                for ctx, r in per.items():
                    fg = parse_colour(r["colour"])
                    if fg is None:
                        continue
                    fgc = over(fg, r["bg"])
                    large = r["size"] >= 24 or (
                        r["size"] >= 18.66 and r["weight"] >= 700
                    )
                    need = 3.0 if large else need_body
                    q = ratio(fgc, r["bg"])
                    per_fg.setdefault((ctx, hexof(fgc)), [fgc, set(), 0])
                    per_fg[(ctx, hexof(fgc))][1].add(hexof(r["bg"]))
                    per_fg[(ctx, hexof(fgc))][2] = max(
                        per_fg[(ctx, hexof(fgc))][2], need
                    )
                    if q < need:
                        k = (where, hexof(fgc), hexof(r["bg"]), round(q, 2))
                        rec = fails.setdefault(
                            k,
                            [text[:32], r["size"], r["weight"], need, [], False],
                        )
                        if ctx not in rec[4]:
                            rec[4].append(ctx)
                        rec[5] = rec[5] or bool(r["own_bg"])
            if focusable(el):
                for ctx, r in per.items():
                    ring = r["ring"]
                    if ring is None:
                        continue
                    ring_count[0] += ctx == "light"
                    tag = f"{page}:{el.line} <{el.tag}>"
                    if ring == "removed":
                        rings_removed.add(where)
                        continue
                    rc = parse_colour(ring)
                    if rc is None:
                        continue
                    rc = over(rc, r["outside"])
                    q = ratio(rc, r["outside"])
                    ring_bgs.setdefault((ctx, hexof(rc)), set()).add(hexof(r["outside"]))
                    if q < 3.0:
                        k = (where + " focus ring", hexof(rc), hexof(r["outside"]), round(q, 2))
                        rec = fails.setdefault(k, ["focus ring vs surround", 0, 0, 3.0, [], False])
                        if ctx not in rec[4]:
                            rec[4].append(ctx)
            if el.tag in FIELDS and el.attrs.get("type") not in HIDDEN_TYPES:
                control_pairs += 1
                for ctx, r in per.items():
                    out_bg = r["outside"]
                    cands = []
                    if r["border"] and parse_colour(r["border"]):
                        cands.append(
                            ("border", over(parse_colour(r["border"]), out_bg))
                        )
                    if r["own_bg"]:
                        cands.append(("fill", over(r["own_bg"], out_bg)))
                    best = (
                        max((ratio(c, out_bg), n, c) for n, c in cands)
                        if cands
                        else (1.0, "none", out_bg)
                    )
                    if best[0] < 3.0:
                        k = (
                            where + " edge",
                            hexof(best[2]),
                            hexof(out_bg),
                            round(best[0], 2),
                        )
                        rec = fails.setdefault(
                            k, [f"field {best[1]} vs surround", 0, 0, 3.0, [], False]
                        )
                        if ctx not in rec[4]:
                            rec[4].append(ctx)
    for (where, fg, bg, q), (text, size, weight, need, ctxs, _) in sorted(
        fails.items()
    ):
        label = "all themes" if len(ctxs) == 3 else ", ".join(ctxs)
        sz = f" {size:g}px/{weight}" if size else ""
        print(
            f'FAIL {label}: {where} "{text}" {fg} on {bg} = {q:.2f}:1, needs {need:g}{sz}'
        )
    text_fails = {
        k: v for k, v in fails.items() if not k[0].endswith((" edge", " focus ring"))
    }
    ring_fails = sorted(
        {(ctx, k[1]) for k, v in fails.items() if k[0].endswith(" focus ring") for ctx in v[4]}
    )
    for ctx, rc in ring_fails:
        bgs = sorted(ring_bgs[(ctx, rc)])
        s = suggest(parse_colour(rc), [parse_colour(b) for b in bgs], 3.0)
        print(
            f"fix {ctx}: focus ring {rc} -> {s or 'none of the same hue'} "
            f"(reaches 3:1 on every surface the ring is drawn on in {ctx}: {', '.join(bgs)}), "
            f"or draw the ring in a token that already does"
        )
    for w in sorted(rings_removed):
        print(f"focus: {w}: outline removed on focus with no box-shadow or outline in its place")
    failing_fgs = {(ctx, k[1]) for k, v in text_fails.items() for ctx in v[4]}
    for ctx, fg in sorted(failing_fgs):
        colour, bgs, need = per_fg[(ctx, fg)]
        ok = sorted(b for b in bgs if ratio(colour, parse_colour(b)) >= need)
        bad = sorted(b for b in bgs if b not in ok)
        if ok:
            print(
                f"fix {ctx}: {fg} passes on {', '.join(ok)} but fails on {', '.join(bad)}: "
                f"that background did not follow the tokens or the theme; fix the background"
            )
            continue
        s = suggest(colour, [parse_colour(b) for b in sorted(bgs)], need)
        print(
            f"fix {ctx}: text {fg} -> {s or 'none of the same hue'} "
            f"(reaches {need:g}:1 on every background it sits on in {ctx}: {', '.join(sorted(bgs))})"
        )
    alts = sorted(
        {(ctx, k[1], k[2], v[3]) for k, v in text_fails.items() if v[5] for ctx in v[4]}
    )
    for ctx, fg, bg, need in alts:
        s = suggest(parse_colour(bg), [parse_colour(fg)], need)
        if s:
            print(
                f"fix {ctx}: or keep text {fg} and move its fill {bg} -> {s} "
                f"(a visible change to the approved colour: a decision for the owner)"
            )
    for p in sorted(parity):
        print(f"parity: {p}")
    for r in raws:
        print(f"raw: {r}")
    unloaded = {f: ps for f, ps in fonts_used.items() if f not in fonts_loaded}
    for f, ps in sorted(unloaded.items()):
        print(
            f"font: {f} is asked for by {', '.join(sorted(ps))} but no @font-face or font link loads it"
        )
    n_fail = len(fails) + len(rings_removed)
    print(
        f"design-pairs: {len(pages)} pages, {text_pairs} text pairs, {control_pairs} controls "
        f"and {ring_count[0]} focus rings "
        f"x {len(CONTEXTS)} contexts (light, dark-attr, dark-media), {n_fail} failing, "
        f"{len(parity)} parity gaps, {len(raws)} raw colours, {len(unloaded)} fonts not loaded; "
        f"{len(rings_removed)} focus removed; "
        f"skipped rules: {stats['skipped_state'] // 3} state, {stats['skipped_media'] // 3} other media, "
        f"{stats['skipped_other'] // 3} unparsed"
    )
    if text_pairs == 0:
        print("design-pairs: 0 text pairs found, nothing checked", file=sys.stderr)
        return 1
    return 1 if n_fail or parity else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
