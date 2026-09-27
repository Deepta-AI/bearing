#!/usr/bin/env python3
"""motion_check: count the animations in the files and prove each moves
only cheap properties and has a reduced-motion path, so the Motion counts
in motion-design's report are computed, not claimed.

What counts as one animation, per stack:
  - web CSS (.css .scss .sass .less, and <style> in .html .vue .svelte):
    each `transition` or `transition-property` declaration that is not
    `none`, and each `@keyframes` block. The same declarations inside
    styled-components templates and quoted style values in .ts/.tsx/.js.
  - web scripts: each Web Animations `.animate(` call, each Motion One
    `animate(el, {...})` call, each Framer Motion or Moti `animate=` prop.
  - React Native: each `useAnimatedStyle(` (Reanimated), each
    `Animated.timing|spring|decay(` and each `LayoutAnimation` call.
  - Compose (.kt): each `animate*AsState(`, `animateContentSize(`,
    `AnimatedVisibility(`, `updateTransition(`, `rememberInfiniteTransition(`.
  - SwiftUI (.swift): each `withAnimation`, `.animation(`, `.transition(`
    and `matchedGeometryEffect(`.

A property outside transform and opacity is a layout or paint property
the doctrine forbids: width, height (and min/max), top, right, bottom,
left, inset, margin, padding, gap, flex-basis, border width, font size,
line height, letter spacing, box-shadow, filter, backdrop-filter, and
`all` (it animates layout by accident). Colour is not counted: the motion
tokens assign hover colour to `duration.instant`. Per stack that is: the
properties in a transition, a keyframes body, a keyframe or animate object
or a useAnimatedStyle body; `useNativeDriver` false or absent on RN
Animated (the native driver only runs transform and opacity; LayoutAnimation
is counted but allowed, since the native side runs it); Compose
`animateContentSize`, expand/shrink transitions, and an animated value
used in a size, padding or offset modifier; SwiftUI an animated state used
in `.frame(` or `.padding(`.

A reduced-motion path exists when the file holds a guard
(prefers-reduced-motion, matchMedia, useReducedMotion, reducedMotion,
isReduceMotionEnabled, ReduceMotion., LocalReducedMotion,
ANIMATOR_DURATION_SCALE, animatorDurationScale, accessibilityReduceMotion)
or a shared tokens module does: a file given with --shared, or a scanned
file named *token*, *motion* or *theme* that holds a guard. A shared
module guards an animation that uses a custom property it resets under
prefers-reduced-motion (`var(--duration-base)`), every CSS animation when
it resets `*` durations, and every animation in a file that imports it.

Usage: motion_check.py [--shared FILE]... <file or dir>...
Prints one problem line per property and per unguarded animation, then
  motion-check: F files scanned, A animations, P properties outside
  transform and opacity, U without a reduced-motion path
and exits 1 on any P or U, on a named path that does not exist, or when
zero files or zero animations were read.
"""

import argparse
import os
import re
import sys

CSS_EXT = {".css", ".scss", ".sass", ".less"}
MARKUP_EXT = {".html", ".htm", ".vue", ".svelte"}
JS_EXT = {".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs"}
KT_EXT = {".kt", ".kts"}
SWIFT_EXT = {".swift"}
ALL_EXT = CSS_EXT | MARKUP_EXT | JS_EXT | KT_EXT | SWIFT_EXT
SKIP_DIRS = {
    "node_modules",
    ".git",
    "dist",
    "build",
    ".next",
    "Pods",
    "coverage",
    ".gradle",
}

FORBIDDEN_CSS = re.compile(
    r"^(all|width|height|min-width|max-width|min-height|max-height|top|right|bottom|left"
    r"|inset(-.*)?|margin(-.*)?|padding(-.*)?|gap|row-gap|column-gap|flex-basis|flex"
    r"|border(-(top|right|bottom|left))?-width|font-size|line-height|letter-spacing"
    r"|box-shadow|filter|backdrop-filter)$"
)
FORBIDDEN_JS = re.compile(
    r"^(width|height|minWidth|maxWidth|minHeight|maxHeight|top|right|bottom|left|inset"
    r"|margin\w*|padding\w*|gap|rowGap|columnGap|flexBasis|borderWidth|border\w+Width"
    r"|fontSize|lineHeight|letterSpacing|boxShadow|shadow\w*|filter|backdropFilter)$"
)
GUARD = re.compile(
    r"prefers-reduced-motion|useReducedMotion|reducedMotion|isReduceMotionEnabled"
    r"|ReduceMotion\.|LocalReducedMotion|ANIMATOR_DURATION_SCALE|animatorDurationScale"
    r"|accessibilityReduceMotion"
)
TIME = re.compile(r"^-?[\d.]+m?s$")
EASING = re.compile(
    r"^(ease|ease-in|ease-out|ease-in-out|linear|step-start|step-end|initial|inherit|unset"
    r"|normal|allow-discrete)$|^(cubic-bezier|steps|linear|var|calc)\("
)
JS_OPTION_KEYS = {
    "duration",
    "easing",
    "delay",
    "iterations",
    "fill",
    "offset",
    "composite",
    "direction",
    "endDelay",
    "iterationStart",
    "type",
    "stiffness",
    "damping",
    "mass",
    "ease",
    "repeat",
    "repeatType",
    "transition",
    "bounce",
    "velocity",
}


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def strip_comments(text, ext):
    """Blank out comments, keeping offsets (so line numbers stay true)."""
    blank = lambda m: re.sub(r"[^\n]", " ", m.group(0))
    text = re.sub(r"/\*.*?\*/", blank, text, flags=re.S)
    if ext in MARKUP_EXT:
        text = re.sub(r"<!--.*?-->", blank, text, flags=re.S)
    if ext in JS_EXT | KT_EXT | SWIFT_EXT | MARKUP_EXT:
        text = re.sub(r"(?<![:\w'\"])//[^\n]*", blank, text)
    return text


def balanced(text, start):
    """The text from text[start] (an opening bracket) to its match."""
    pairs = {"(": ")", "[": "]", "{": "}"}
    open_ch = text[start]
    close_ch = pairs[open_ch]
    depth = 0
    for i in range(start, len(text)):
        if text[i] == open_ch:
            depth += 1
        elif text[i] == close_ch:
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
    return text[start:]


def split_top(value):
    """Split on commas outside parentheses."""
    out, cur, depth = [], "", 0
    for ch in value:
        depth += ch == "("
        depth -= ch == ")"
        if ch == "," and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    out.append(cur)
    return [p.strip() for p in out if p.strip()]


def transition_props(value, prop_only):
    """Property names in a transition (or transition-property) value."""
    props = []
    for group in split_top(value):
        if prop_only:
            props.append(group.split()[0])
            continue
        for tok in re.findall(r"[\w-]+\([^)]*\)|[^\s]+", group):
            if TIME.match(tok) or EASING.search(tok) or re.match(r"^[\d.]+$", tok):
                continue
            props.append(tok)
            break
    return props


class Scan:
    def __init__(self):
        self.anims = []  # (path, line, kind, text, css_kind)
        self.props = []  # (path, line, kind, prop)
        self.files = 0

    def anim(self, path, text, pos, kind, body, css_kind=False):
        self.anims.append((path, line_of(text, pos), kind, body, css_kind))

    def prop(self, path, text, pos, kind, prop):
        self.props.append((path, line_of(text, pos), kind, prop))


def scan_css(s, path, text, in_js):
    decl = re.compile(
        r"(?<![\w-])(transition-property|transition)\s*:\s*([^;{}\n]*)", re.I
    )
    for m in decl.finditer(text):
        raw = m.group(2).strip()
        if in_js:
            quoted = re.findall(r"[\"'`]([^\"'`]*)[\"'`]", raw)
            if quoted:
                values = quoted
            elif re.search(r"\d(ms|s)\b|var\(--", raw):
                values = [raw]  # a styled-components or css`` template
            else:
                continue  # an object or a variable, not a CSS value
        else:
            values = [raw]
        values = [
            v.strip().rstrip(",") for v in values if v.strip() and v.strip() != "none"
        ]
        if not values:
            continue
        s.anim(path, text, m.start(), m.group(1).lower(), m.group(0), True)
        for v in values:
            for p in transition_props(v, m.group(1).lower() == "transition-property"):
                if FORBIDDEN_CSS.match(p.lower()):
                    s.prop(path, text, m.start(), m.group(1).lower(), p.lower())
    for m in re.finditer(r"@(?:-webkit-)?keyframes\s+([\w-]+)\s*\{", text):
        body = balanced(text, m.end() - 1)
        s.anim(path, text, m.start(), f"@keyframes {m.group(1)}", body, True)
        seen = set()
        for d in re.finditer(r"([\w-]+)\s*:", body):
            p = d.group(1).lower()
            if FORBIDDEN_CSS.match(p) and p not in seen:
                seen.add(p)
                s.prop(path, text, m.start() + d.start(), f"@keyframes {m.group(1)}", p)


def object_keys(body):
    return [
        (k.start(), k.group(1))
        for k in re.finditer(r"[{,\s\[]['\"]?(\w+)['\"]?\s*:", body)
    ]


def check_keys(s, path, text, base, kind, body):
    seen = set()
    for off, key in object_keys(body):
        if key in JS_OPTION_KEYS or key in seen:
            continue
        if FORBIDDEN_JS.match(key):
            seen.add(key)
            s.prop(path, text, base + off, kind, key)


def scan_js(s, path, text):
    for m in re.finditer(r"\.animate\(\s*", text):
        s.anim(path, text, m.start(), ".animate()", text[m.start() : m.start() + 200])
        if m.end() < len(text) and text[m.end()] in "[{":
            check_keys(s, path, text, m.end(), ".animate()", balanced(text, m.end()))
    for m in re.finditer(r"(?<![.\w])animate\(\s*[^,()]+,\s*\{", text):
        s.anim(path, text, m.start(), "animate()", text[m.start() : m.start() + 200])
        check_keys(s, path, text, m.end() - 1, "animate()", balanced(text, m.end() - 1))
    for m in re.finditer(r"(?<![\w-])animate=\{", text):
        s.anim(path, text, m.start(), "animate=", text[m.start() : m.start() + 200])
    for m in re.finditer(r"(?<![\w-])(initial|animate|exit|while\w+)=\{\{", text):
        check_keys(
            s, path, text, m.end() - 1, m.group(1) + "=", balanced(text, m.end() - 1)
        )
    for m in re.finditer(r"\buseAnimatedStyle\(", text):
        body = balanced(text, m.end() - 1)
        s.anim(path, text, m.start(), "useAnimatedStyle", body)
        check_keys(s, path, text, m.end() - 1, "useAnimatedStyle", body)
    for m in re.finditer(r"\bAnimated\.(timing|spring|decay)\(", text):
        body = balanced(text, m.end() - 1)
        kind = f"Animated.{m.group(1)}"
        s.anim(path, text, m.start(), kind, body)
        if not re.search(r"useNativeDriver\s*:\s*true", body):
            s.prop(
                path,
                text,
                m.start(),
                kind,
                "useNativeDriver off (layout on the JS thread)",
            )
    for m in re.finditer(
        r"\bLayoutAnimation\.(configureNext|easeInEaseOut|linear|spring)\(", text
    ):
        # LayoutAnimation runs the next layout pass on the native side: it is
        # the core way to close a gap after a row leaves without animating
        # height from JavaScript, so it counts as an animation, not a problem.
        s.anim(path, text, m.start(), "LayoutAnimation", m.group(0))


def scan_kotlin(s, path, text):
    names = []
    for m in re.finditer(
        r"(?:val|var)\s+(\w+)\s*(?:by|=)\s*(animate\w*AsState)\(", text
    ):
        names.append(m.group(1))
    for m in re.finditer(r"\b(animate\w*AsState)\(", text):
        s.anim(path, text, m.start(), m.group(1), text[m.start() : m.start() + 200])
        if re.match(r"animate(Size|IntSize)AsState", m.group(1)):
            s.prop(path, text, m.start(), m.group(1), "size")
    for m in re.finditer(r"\banimateContentSize\(", text):
        s.anim(path, text, m.start(), "animateContentSize", m.group(0))
        s.prop(path, text, m.start(), "animateContentSize", "height")
    for m in re.finditer(r"\bAnimatedVisibility\(", text):
        body = balanced(text, m.end() - 1)
        s.anim(path, text, m.start(), "AnimatedVisibility", body)
        for e in re.finditer(
            r"\b(expand|shrink)(Vertically|Horizontally|In|Out)\b", body
        ):
            s.prop(path, text, m.start(), "AnimatedVisibility", e.group(0))
    for m in re.finditer(r"\b(updateTransition|rememberInfiniteTransition)\(", text):
        s.anim(path, text, m.start(), m.group(1), m.group(0))
    for n in names:
        for u in re.finditer(
            r"\.(width|height|size|padding|requiredWidth|requiredHeight|heightIn|widthIn|offset)\(([^)]*)\b"
            + re.escape(n)
            + r"\b",
            text,
        ):
            s.prop(path, text, u.start(), f"animated {n}", u.group(1))


def scan_swift(s, path, text):
    names = set()
    for m in re.finditer(r"\bwithAnimation\b", text):
        s.anim(path, text, m.start(), "withAnimation", m.group(0))
        brace = text.find("{", m.end())
        if brace >= 0:
            body = balanced(text, brace)
            names |= set(re.findall(r"\b(\w+)\s*(?:=[^=]|\.toggle\(\))", body))
    for m in re.finditer(r"\.animation\(", text):
        body = balanced(text, m.end() - 1)
        s.anim(path, text, m.start(), ".animation", body)
        v = re.search(r"value:\s*(\w+)", body)
        if v:
            names.add(v.group(1))
    for m in re.finditer(r"\.(transition|matchedGeometryEffect)\(", text):
        s.anim(path, text, m.start(), "." + m.group(1), m.group(0))
    for n in names:
        for u in re.finditer(
            r"\.(frame|padding)\(([^)]*)\b" + re.escape(n) + r"\b", text
        ):
            s.prop(path, text, u.start(), f"animated {n}", u.group(1))


def shared_guards(paths):
    """(css vars zeroed, global css reset, module basenames) from the shared files."""
    zeroed, reset, bases = set(), False, set()
    for p in paths:
        try:
            text = open(p, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        if not GUARD.search(text):
            continue
        bases.add(os.path.splitext(os.path.basename(p))[0])
        for m in re.finditer(r"@media[^{]*prefers-reduced-motion[^{]*\{", text):
            block = balanced(text, m.end() - 1)
            zeroed |= set(re.findall(r"(--[\w-]+)\s*:", block))
            if re.search(r"(^|[\s,{])\*", block) and re.search(
                r"(transition|animation)(-duration)?\s*:[^;]*(!important|none|0)", block
            ):
                reset = True
    return zeroed, reset, bases


def walk(targets):
    """(files with a scanned extension, count of named paths that do not exist)."""
    files, missing = [], 0
    for t in targets:
        if os.path.isdir(t):
            for root, dirs, names in os.walk(t):
                dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
                for n in sorted(names):
                    if os.path.splitext(n)[1] in ALL_EXT:
                        files.append(os.path.join(root, n))
        elif os.path.isfile(t):
            if os.path.splitext(t)[1] in ALL_EXT:
                files.append(t)
        else:
            print(f"problem: {t}: no such file or directory")
            missing += 1
    return files, missing


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shared", action="append", default=[])
    ap.add_argument("paths", nargs="*")
    a = ap.parse_args()
    files, missing = walk(a.paths)
    if not files:
        print(
            "motion-check: 0 files scanned, 0 animations, 0 properties outside transform and opacity, 0 without a reduced-motion path"
        )
        print("motion-check: 0 files scanned, nothing checked", file=sys.stderr)
        return 1
    auto_shared = [
        f for f in files if re.search(r"token|motion|theme", os.path.basename(f), re.I)
    ]
    zeroed, reset, bases = shared_guards(a.shared + auto_shared)

    s = Scan()
    guarded_files, imports = set(), {}
    for f in files:
        ext = os.path.splitext(f)[1]
        text = strip_comments(open(f, encoding="utf-8", errors="replace").read(), ext)
        s.files += 1
        if GUARD.search(text):
            guarded_files.add(f)
        imports[f] = any(
            re.search(
                r"""(from|import|@import|@use|require\()\s*\(?\s*['"][^'"]*\b"""
                + re.escape(b)
                + r"""(\.\w+)?['"]""",
                text,
            )
            for b in bases
        )
        if ext in CSS_EXT or ext in MARKUP_EXT:
            scan_css(s, f, text, in_js=False)
        if ext in JS_EXT:
            scan_css(s, f, text, in_js=True)
        if ext in JS_EXT or ext in MARKUP_EXT:
            scan_js(s, f, text)
        if ext in KT_EXT:
            scan_kotlin(s, f, text)
        if ext in SWIFT_EXT:
            scan_swift(s, f, text)

    unguarded = []
    for path, line, kind, body, css_kind in s.anims:
        if path in guarded_files or imports.get(path):
            continue
        if css_kind and (
            reset or any(v in zeroed for v in re.findall(r"var\((--[\w-]+)", body))
        ):
            continue
        unguarded.append((path, line, kind))

    for path, line, kind, prop in s.props:
        print(
            f"problem: {path}:{line}: {kind} animates {prop}; move only transform and opacity"
        )
    for path, line, kind in unguarded:
        print(
            f"problem: {path}:{line}: {kind} has no reduced-motion path in the file or a shared tokens module"
        )
    print(
        f"motion-check: {s.files} files scanned, {len(s.anims)} animations, "
        f"{len(s.props)} properties outside transform and opacity, "
        f"{len(unguarded)} without a reduced-motion path"
    )
    if not s.anims:
        print(
            f"motion-check: 0 animations in {s.files} files, nothing checked",
            file=sys.stderr,
        )
        return 1
    return 1 if s.props or unguarded or missing else 0


if __name__ == "__main__":
    sys.exit(main())
