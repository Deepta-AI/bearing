#!/usr/bin/env python3
"""bundle: audit, check and render the product's design bundle under docs/design.

  bundle.py audit   [--design docs/design] [--flows-root docs/design/flows]
  bundle.py check   [--design docs/design] [--flows-root docs/design/flows]
  bundle.py gallery [--design docs/design] [--template <skill>/templates/gallery.html]

The bundle is design.json (the manifest, shaped by templates/design.schema.json),
the screens it lists (screens/<feature>/<id>-<name>.html), the shared tokens.css,
index.html (the gallery) and, when design-system ran, design-system.html.

audit counts, from the files, and writes the lists into design.json's audit block:
  missing_screens     a manifest path with no file, or a flows inventory screen
                      the manifest does not list
  missing_states      a manifest state with no data-state panel in the screen
  missing_chrome      a state panel without its frames (data-frame="desktop" and
                      "mobile"; mobile only when platform is mobile), or a frame
                      without an app chrome slot (data-app-chrome; "none: <reason>"
                      is allowed for a screen with no chrome by design)
  unannotated_states  a state panel without a data-annotation of six words or more
                      saying what changed from the default and why
  dead_links          a relative href or src, in any bundle page, whose file is absent
  missing_nav_links   an edge of a flows navigation map (S-01 --> S-02) with no link
                      from the first screen's file to the second's
  external_refs       an http(s) reference other than Google Fonts
  hardcoded_colours   a colour literal in a screen's style block or style attribute
                      (tokens.css, or an inline <style data-tokens> copy, is exempt)
  unlinked_tokens     a screen that neither links an existing tokens.css nor carries
                      the tokens inline
  uncovered_stories   a story (design.json stories plus every flows Serves column)
                      no screen serves and no concern names

check recomputes the same lists and fails when the audit block is null or has a
null field (the audit never ran), when a recorded list differs from the files
(the audit is stale), when any list is non-empty, when the manifest breaks the
schema, when index.html does not link every screen, and when DESIGN-SYNC.md is
absent. audit fails on the same findings after writing them.

gallery renders index.html from design.json: the sitemap tree, the navigation
and its reason, one card per screen (purpose, platform, states, serves, the
concerns raised on it) and the audit numbers.

Every command prints its problems and one count line; each exits 1 on any
problem, and when design.json lists zero screens.
"""

import argparse
import datetime
import glob
import html
import importlib.util
import json
import os
import re
import sys
from html.parser import HTMLParser

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)
SCHEMA = os.path.join(SKILL, "templates", "design.schema.json")
GALLERY = os.path.join(SKILL, "templates", "gallery.html")
FLOWS_CHECK = os.path.join(SKILL, "..", "ux-flows", "scripts", "flows_check.py")
FIELDS = [
    "missing_screens",
    "missing_states",
    "missing_chrome",
    "unannotated_states",
    "dead_links",
    "missing_nav_links",
    "external_refs",
    "hardcoded_colours",
    "unlinked_tokens",
    "uncovered_stories",
]
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
FONT_HOSTS = ("https://fonts.googleapis.com", "https://fonts.gstatic.com")
STORY = re.compile(r"\b[A-Z]{2,5}-\d{2,3}(?:-\d{2,4})?\b")


def load_flows_check():
    if not os.path.isfile(FLOWS_CHECK):
        return None
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("flows_check", FLOWS_CHECK)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------- schema


def validate(node, schema, root, where, out):
    if "$ref" in schema:
        name = schema["$ref"].split("/")[-1]
        schema = root["$defs"][name]
    t = schema.get("type")
    kinds = {
        "object": dict,
        "array": list,
        "string": str,
        "integer": int,
        "boolean": bool,
        "null": type(None),
    }
    if t:
        allowed = t if isinstance(t, list) else [t]
        if not any(isinstance(node, kinds[k]) for k in allowed) or (
            isinstance(node, bool) and "boolean" not in allowed
        ):
            out.append("%s: expected %s" % (where, " or ".join(allowed)))
            return
    if "enum" in schema and node not in schema["enum"]:
        out.append("%s: %r is not one of %s" % (where, node, ", ".join(schema["enum"])))
    if isinstance(node, int) and "minimum" in schema and node < schema["minimum"]:
        out.append("%s: below %s" % (where, schema["minimum"]))
    if isinstance(node, dict):
        for k in schema.get("required", []):
            if k not in node:
                out.append("%s: missing %s" % (where, k))
        for k, sub in schema.get("properties", {}).items():
            if k in node:
                validate(node[k], sub, root, "%s.%s" % (where, k), out)
    if isinstance(node, list):
        if len(node) < schema.get("minItems", 0):
            out.append("%s: needs at least %d items" % (where, schema["minItems"]))
        if "items" in schema:
            for i, item in enumerate(node):
                validate(item, schema["items"], root, "%s[%d]" % (where, i), out)


# ---------------------------------------------------------------- html


class Page(HTMLParser):
    """Links, style attributes, and per state panel: frames, chrome, annotation."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.refs = []
        self.style_attrs = []
        self.stylesheets = []
        self.panels = {}  # state -> {"frames": {name: chrome}, "annotation": text}
        self.order = []
        self.capture = None

    def _panel(self):
        for tag, a in reversed(self.stack):
            if a.get("data-state"):
                return a["data-state"].lower()
        return None

    def _frame(self):
        for tag, a in reversed(self.stack):
            if a.get("data-frame"):
                return a["data-frame"].lower()
        return None

    def handle_starttag(self, tag, attrs):
        a = {k: (v if v is not None else "") for k, v in attrs}
        for k in ("href", "src"):
            if a.get(k):
                self.refs.append(a[k])
        if a.get("style"):
            self.style_attrs.append(a["style"])
        if tag == "link" and "stylesheet" in a.get("rel", ""):
            self.stylesheets.append(a.get("href", ""))
        if tag in VOID:
            self._mark(tag, a)
            return
        self.stack.append((tag, a))
        self._mark(tag, a)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in VOID:
            self.handle_endtag(tag)

    def _mark(self, tag, a):
        if a.get("data-state") and not self._outer_panel_exists():
            st = a["data-state"].lower()
            if st not in self.panels:
                self.panels[st] = {"frames": {}, "annotation": ""}
                self.order.append(st)
        st = self._panel()
        if st is None:
            return
        if a.get("data-frame"):
            self.panels[st]["frames"].setdefault(a["data-frame"].lower(), None)
        if "data-app-chrome" in a:
            fr = self._frame()
            if fr is not None:
                self.panels[st]["frames"][fr] = a["data-app-chrome"]
        if "data-annotation" in a and tag not in VOID:
            self.capture = (st, len(self.stack))

    def _outer_panel_exists(self):
        return sum(1 for _, a in self.stack if a.get("data-state")) > 1

    def handle_data(self, data):
        if self.capture:
            st, _ = self.capture
            self.panels[st]["annotation"] += data

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                if self.capture and i < self.capture[1]:
                    self.capture = None
                del self.stack[i:]
                return


def parse(path):
    p = Page()
    text = open(path, encoding="utf-8", errors="replace").read()
    p.feed(text)
    return p, text


def local_target(base_file, ref):
    ref = ref.strip()
    if not ref or ref.startswith(
        ("#", "mailto:", "tel:", "data:", "javascript:", "//")
    ):
        return None
    if re.match(r"^[a-z][a-z0-9+.-]*:", ref, re.I):
        return None
    ref = ref.split("#", 1)[0].split("?", 1)[0]
    if not ref:
        return None
    return os.path.normpath(os.path.join(os.path.dirname(base_file), ref))


def colour_literals(text, attrs):
    text = re.sub(
        r"<style[^>]*\bdata-tokens\b[^>]*>.*?</style>", "", text, flags=re.S | re.I
    )
    hits = []
    for css in re.findall(r"<style[^>]*>(.*?)</style>", text, re.S | re.I):
        css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
        hits += COLOUR.findall(css)
    for s in attrs:
        hits += COLOUR.findall(s)
    return hits


# ---------------------------------------------------------------- flows


def flows_facts(root, fc):
    """{feature: {"screens": [ids], "edges": [(a, b)], "stories": set(), "path": file}}."""
    out = {}
    if not fc or not root or not os.path.isdir(root):
        return out
    for path in fc.pick_files(root):
        feature = os.path.basename(os.path.dirname(path))
        text = fc.read(path)
        screens, _ = fc.inventory(text)
        labels, edges, seen, terminal = {}, set(), set(), set()
        for block in fc.flowcharts(fc.section(text, "Navigation map")):
            fc.parse_block(block, labels, edges, seen, terminal)
        pairs = set()
        for x, y in edges:
            a, b = fc.screen_of(x, labels), fc.screen_of(y, labels)
            if a and b and a != b:
                pairs.add((a, b))
        stories = set()
        for line in fc.section(text, "Screen inventory").split("\n"):
            if line.startswith("|") and re.match(r"^\|\s*S-\d", line):
                stories |= set(
                    STORY.findall(line.split("|")[4] if line.count("|") > 4 else "")
                )
        out[feature] = {
            "screens": screens,
            "edges": sorted(pairs),
            "stories": {s for s in stories if not s.startswith("S-")},
            "path": path,
        }
    return out


# ---------------------------------------------------------------- audit


def compute(design_dir, flows_root):
    """(manifest, findings dict, counts dict, problems that are not findings)."""
    mpath = os.path.join(design_dir, "design.json")
    other = []
    try:
        manifest = json.load(open(mpath, encoding="utf-8"))
    except (OSError, ValueError) as e:
        return None, None, None, ["cannot read %s: %s" % (mpath, e)]
    schema = json.load(open(SCHEMA, encoding="utf-8"))
    validate(manifest, schema, schema, "design.json", other)
    screens = manifest.get("screens") or []
    if not isinstance(screens, list):
        screens = []
    f = {k: [] for k in FIELDS}
    counts = {
        "screens": len(screens),
        "panels": 0,
        "links": 0,
        "stories": 0,
        "features": 0,
    }
    keys = {s.get("key") for s in screens if isinstance(s, dict)}

    def walk(nodes, where):
        for n in nodes or []:
            if isinstance(n, dict):
                if n.get("screen") and n["screen"] not in keys:
                    other.append(
                        "sitemap %s names unknown screen %s" % (where, n["screen"])
                    )
                walk(n.get("children"), where + "/" + str(n.get("name", "?")))

    walk(manifest.get("sitemap"), "")
    chosen = [
        d
        for d in manifest.get("directions") or []
        if isinstance(d, dict) and d.get("chosen")
    ]
    if manifest.get("directions") and len(chosen) != 1:
        other.append("directions: %d marked chosen, want exactly 1" % len(chosen))

    fc = load_flows_check()
    if fc is None:
        print(
            "note: ux-flows/scripts/flows_check.py not found, flows checks skipped"
        )
    flows = flows_facts(flows_root, fc)
    counts["flows"] = len(flows)
    counts["features"] = len(
        {str(s.get("key", "")).split("/")[0] for s in screens if isinstance(s, dict)}
    )

    files = {}  # screen key -> (abs path, Page, text)
    for s in screens:
        if not isinstance(s, dict):
            continue
        key, rel = s.get("key", "?"), s.get("path", "")
        path = os.path.normpath(os.path.join(design_dir, rel))
        if not rel or not os.path.isfile(path):
            f["missing_screens"].append("%s: no file at %s" % (key, rel or "(no path)"))
            continue
        page, text = parse(path)
        files[key] = (path, page, text)
        counts["panels"] += len(page.order)
        for st in s.get("states") or []:
            if str(st).lower() not in page.panels:
                f["missing_states"].append('%s: no data-state="%s" panel' % (key, st))
        want = ["mobile"] if s.get("platform") == "mobile" else ["desktop", "mobile"]
        for st in page.order:
            panel = page.panels[st]
            for fr in want:
                if fr not in panel["frames"]:
                    f["missing_chrome"].append(
                        '%s: state %s has no data-frame="%s"' % (key, st, fr)
                    )
            for fr, chrome in sorted(panel["frames"].items()):
                c = (chrome or "").strip()
                if not c:
                    f["missing_chrome"].append(
                        "%s: state %s, %s frame has no data-app-chrome slot"
                        % (key, st, fr)
                    )
                elif (
                    c.lower().startswith("none")
                    and len(c.split(":", 1)[-1].strip()) < 3
                ):
                    f["missing_chrome"].append(
                        '%s: state %s, %s frame says data-app-chrome="none" without a reason'
                        % (key, st, fr)
                    )
            if len(panel["annotation"].split()) < 6:
                f["unannotated_states"].append(
                    "%s: state %s has no data-annotation saying what changed and why"
                    % (key, st)
                )
        hard = colour_literals(text, page.style_attrs)
        if hard:
            f["hardcoded_colours"].append(
                "%s: %d (first %s)" % (key, len(hard), hard[0])
            )
        linked = False
        for h in page.stylesheets:
            t = local_target(path, h)
            if t and t.endswith("tokens.css") and os.path.isfile(t):
                linked = True
        if not linked and not re.search(r"<style[^>]*\bdata-tokens\b", text, re.I):
            f["unlinked_tokens"].append(
                "%s: links no tokens.css and carries none inline" % key
            )

    # Flows: every inventory screen is in the manifest; every navigation edge is a link.
    by_feature_id = {}
    for key in keys:
        if key and "/" in key:
            feat, sid = key.split("/", 1)
            by_feature_id[(feat, sid)] = key
    for feat, facts in sorted(flows.items()):
        for sid in facts["screens"]:
            if (feat, sid) not in by_feature_id:
                f["missing_screens"].append(
                    "%s/%s: in %s, not in design.json"
                    % (feat, sid, os.path.relpath(facts["path"], design_dir))
                )
        for a, b in facts["edges"]:
            ka, kb = by_feature_id.get((feat, a)), by_feature_id.get((feat, b))
            if not ka or not kb or ka not in files or kb not in files:
                continue
            src_path, src_page, _ = files[ka]
            dst = files[kb][0]
            if not any(local_target(src_path, r) == dst for r in src_page.refs):
                f["missing_nav_links"].append(
                    "%s -> %s: the navigation map has this edge, %s has no link to %s"
                    % (ka, kb, os.path.basename(src_path), os.path.basename(dst))
                )

    # Links and external references across every page in the bundle.
    pages = sorted(
        set(
            glob.glob(os.path.join(design_dir, "*.html"))
            + glob.glob(os.path.join(design_dir, "screens", "*", "*.html"))
        )
    )
    for pg in pages:
        p, _ = parse(pg)
        rel = os.path.relpath(pg, design_dir)
        for r in p.refs:
            if re.match(r"^https?://", r, re.I):
                if not r.startswith(FONT_HOSTS):
                    f["external_refs"].append("%s: %s" % (rel, r))
                continue
            t = local_target(pg, r)
            if t is None:
                continue
            counts["links"] += 1
            if not os.path.exists(t):
                f["dead_links"].append("%s: %s points at no file" % (rel, r))

    stories = set(manifest.get("stories") or [])
    for facts in flows.values():
        stories |= facts["stories"]
    served = set()
    for s in screens:
        if isinstance(s, dict):
            served |= set(s.get("serves") or [])
    raised = " ".join(
        str(c.get("detail", ""))
        for c in manifest.get("concerns") or []
        if isinstance(c, dict)
    )
    counts["stories"] = len(stories)
    for sid in sorted(stories - served):
        if sid not in raised:
            f["uncovered_stories"].append(
                "%s: no screen serves it and no concern names it" % sid
            )

    for k in f:
        f[k] = sorted(set(f[k]))
    return manifest, f, counts, other


def report(cmd, f, counts, problems):
    for p in problems:
        print("problem: %s" % p)
    total = sum(len(v) for v in f.values()) if f else 0
    detail = (
        ", ".join("%s %d" % (k.replace("_", " "), len(f[k])) for k in FIELDS)
        if f
        else ""
    )
    print(
        "design-bundle %s: %d screens (%d features), %d state panels, %d links checked, "
        "%d flows files, %d stories, %d audit findings (%s), %d problems"
        % (
            cmd,
            counts.get("screens", 0),
            counts.get("features", 0),
            counts.get("panels", 0),
            counts.get("links", 0),
            counts.get("flows", 0),
            counts.get("stories", 0),
            total,
            detail,
            len(problems),
        )
    )


def findings_as_problems(f):
    return ["%s: %s" % (k, item) for k in FIELDS for item in f[k]]


def audit(args):
    manifest, f, counts, other = compute(args.design, args.flows_root)
    if manifest is None:
        report("audit", None, {}, other)
        return 1
    if counts["screens"] == 0:
        report(
            "audit", f, counts, other + ["0 screens in design.json, nothing checked"]
        )
        return 1
    manifest["audit"] = dict(
        {"ran_on": datetime.date.today().isoformat(), "checked": counts},
        **{k: f[k] for k in FIELDS},
    )
    mpath = os.path.join(args.design, "design.json")
    with open(mpath, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    problems = other + findings_as_problems(f)
    report("audit", f, counts, problems)
    return 1 if problems else 0


def check(args):
    manifest, f, counts, other = compute(args.design, args.flows_root)
    if manifest is None:
        report("check", None, {}, other)
        return 1
    problems = list(other)
    if counts["screens"] == 0:
        problems.append("0 screens in design.json, nothing checked")
    recorded = manifest.get("audit")
    if not isinstance(recorded, dict):
        problems.append(
            "design.json audit is null: the audit never ran (run bundle.py audit)"
        )
    else:
        for k in FIELDS:
            got = recorded.get(k)
            if got is None:
                problems.append("design.json audit.%s is null: the audit never ran" % k)
            elif sorted(got) != f[k]:
                problems.append(
                    "design.json audit.%s is stale: recorded %d, the files give %d (run bundle.py audit)"
                    % (k, len(got), len(f[k]))
                )
    problems += findings_as_problems(f)
    gallery = os.path.join(args.design, "index.html")
    if not os.path.isfile(gallery):
        problems.append("no index.html gallery (run bundle.py gallery)")
    else:
        g, _ = parse(gallery)
        linked = {local_target(gallery, r) for r in g.refs}
        for s in manifest.get("screens") or []:
            if isinstance(s, dict) and s.get("path"):
                if os.path.normpath(os.path.join(args.design, s["path"])) not in linked:
                    problems.append("index.html does not link %s" % s["path"])
    if not os.path.isfile(os.path.join(args.design, "DESIGN-SYNC.md")):
        problems.append("no DESIGN-SYNC.md (templates/DESIGN-SYNC.md)")
    report("check", f, counts, problems)
    return 1 if problems else 0


# ---------------------------------------------------------------- gallery


def esc(x):
    return html.escape(str(x if x is not None else ""))


def tree(nodes, by_key):
    if not nodes:
        return ""
    out = ["<ul>"]
    for n in nodes:
        if not isinstance(n, dict):
            continue
        s = by_key.get(n.get("screen"))
        label = esc(n.get("name", "?"))
        if s:
            label = '<a href="%s">%s</a> <span class="key">%s</span>' % (
                esc(s.get("path")),
                label,
                esc(s.get("key")),
            )
        out.append("<li>%s%s</li>" % (label, tree(n.get("children"), by_key)))
    out.append("</ul>")
    return "".join(out)


def gallery(args):
    mpath = os.path.join(args.design, "design.json")
    try:
        m = json.load(open(mpath, encoding="utf-8"))
    except (OSError, ValueError) as e:
        print("problem: cannot read %s: %s" % (mpath, e))
        print("design-bundle gallery: 0 screens rendered")
        return 1
    screens = [s for s in m.get("screens") or [] if isinstance(s, dict)]
    if not screens:
        print("problem: 0 screens in design.json, nothing rendered")
        print("design-bundle gallery: 0 screens rendered")
        return 1
    by_key = {s.get("key"): s for s in screens}
    concerns = [c for c in m.get("concerns") or [] if isinstance(c, dict)]
    cards = []
    for s in screens:
        raised = [c for c in concerns if c.get("screen") == s.get("key")]
        states = " ".join(
            '<a href="%s#state=%s">%s</a>' % (esc(s.get("path")), esc(st), esc(st))
            for st in s.get("states") or []
        )
        cards.append(
            '<li class="card" id="%s"><h3><a href="%s">%s</a></h3>'
            '<p class="key">%s &middot; %s</p><p>%s</p>'
            '<p class="states">States: %s</p><p class="serves">Serves %s</p>%s%s</li>'
            % (
                esc(re.sub(r"[^a-z0-9]+", "-", str(s.get("key", "")).lower())),
                esc(s.get("path")),
                esc(s.get("name")),
                esc(s.get("key")),
                esc(s.get("platform")),
                esc(s.get("purpose")),
                states,
                esc(", ".join(s.get("serves") or []) or "no story"),
                ('<p class="notes">%s</p>' % esc(s["notes"])) if s.get("notes") else "",
                (
                    '<div class="raised"><p>Raised while designing</p><ul>%s</ul></div>'
                    % "".join(
                        "<li><b>%s</b> %s</li>"
                        % (esc(c.get("kind")), esc(c.get("detail")))
                        for c in raised
                    )
                )
                if raised
                else "",
            )
        )
    nav = m.get("navigation") or {}
    navigation = (
        "<dl><dt>Desktop</dt><dd>%s</dd><dt>Mobile</dt><dd>%s</dd><dt>Why</dt><dd>%s</dd></dl>"
        % (esc(nav.get("desktop")), esc(nav.get("mobile")), esc(nav.get("why")))
    )
    general = [c for c in concerns if not c.get("screen")]
    concern_html = (
        "<ul>%s</ul>"
        % "".join(
            "<li><b>%s</b> %s</li>" % (esc(c.get("kind")), esc(c.get("detail")))
            for c in general
        )
        if general
        else "<p>None beyond those on the screen cards.</p>"
    )
    a = m.get("audit")
    if isinstance(a, dict):
        audit_html = '<p>Ran on %s.</p><dl class="audit">%s</dl>' % (
            esc(a.get("ran_on")),
            "".join(
                "<dt>%s</dt><dd>%d</dd>"
                % (esc(k.replace("_", " ")), len(a.get(k) or []))
                for k in FIELDS
            ),
        )
    else:
        audit_html = "<p>Not run. Run bundle.py audit before sharing this bundle.</p>"
    directions = "".join(
        "<li><b>%s</b>%s %s</li>"
        % (
            esc(d.get("name")),
            " (chosen)" if d.get("chosen") else "",
            esc(d.get("rationale")),
        )
        for d in m.get("directions") or []
        if isinstance(d, dict)
    )
    system = (
        '<a href="design-system.html">The design system</a>: tokens and every component in every state, light and dark.'
        if os.path.isfile(os.path.join(args.design, "design-system.html"))
        else "No design-system.html yet (design-system writes it)."
    )
    brief = m.get("brief") or {}
    page = open(args.template, encoding="utf-8").read()
    fills = {
        "{{PRODUCT}}": esc(m.get("product", "Product")),
        "{{VERSION}}": esc(m.get("version", "?")),
        "{{SUMMARY}}": "%d screens across %d features. %s"
        % (
            len(screens),
            len({str(s.get("key", "")).split("/")[0] for s in screens}),
            esc(brief.get("surface", "")),
        ),
        "{{BRIEF}}": "<dl><dt>Audience</dt><dd>%s</dd><dt>Must feel</dt><dd>%s</dd><dt>Avoid</dt><dd>%s</dd></dl>"
        % (
            esc(brief.get("audience")),
            esc(brief.get("must_feel")),
            esc(brief.get("avoid")),
        ),
        "{{DIRECTIONS}}": "<ul>%s</ul>" % directions,
        "{{SYSTEM_LINK}}": system,
        "{{SITEMAP}}": tree(m.get("sitemap"), by_key),
        "{{NAVIGATION}}": navigation,
        "{{SCREENS}}": "\n".join(cards),
        "{{CONCERNS}}": concern_html,
        "{{AUDIT}}": audit_html,
    }
    for k, v in fills.items():
        page = page.replace(k, v)
    out = os.path.join(args.design, "index.html")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(page)
    print(
        "design-bundle gallery: %d screens rendered, %d concerns, wrote %s"
        % (len(screens), len(concerns), out)
    )
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("audit", "check", "gallery"):
        p = sub.add_parser(name)
        p.add_argument("--design", default="docs/design")
        p.add_argument("--flows-root", default=None)
        if name == "gallery":
            p.add_argument("--template", default=GALLERY)
    args = ap.parse_args()
    if args.flows_root is None:
        args.flows_root = os.path.join(args.design, "flows")
    return {"audit": audit, "check": check, "gallery": gallery}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
