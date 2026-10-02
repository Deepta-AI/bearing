#!/usr/bin/env python3
"""ref_check: generated tests only reference things that exist in the source.

A generated test that targets a test id, a label, a button name or a route
the application does not have is an invented API: it fails for the wrong
reason, or worse, is healed into passing against nothing. This reads the
test files and extracts what they reference:

  ids    getByTestId('x'), [data-testid="x"], Maestro id: "x",
         withId(R.id.x), accessibilityIdentifier / app.buttons["x"]
  names  getByRole(..., { name: 'x' }), getByText('x'), getByLabel('x'),
         getByPlaceholder('x'), Maestro tapOn: "x", onNodeWithText("x")
  paths  page.goto('/x'), request.get|post|put|patch|delete('/x'),
         client.get|post(...)("/x"), httptest.NewRequest(M, "/x", ...),
         http.NewRequest(M, "/x", ...), and any call whose arguments give a
         method and then a path, which is how suites reach routes through
         their own helper: do(t, h, http.MethodPost, "/orders/"+id, body),
         call("DELETE", "/items/A-1")

and looks for each in the source tree (test directories, node_modules,
build output and .git excluded). An id must appear as written; a name must
too, or be what a template literal in the source renders to
(`Delete up to ${n} records` covers "Delete up to 3 records"). A
path is compared segment by segment with every route literal in the source
("/orders/{id}/refunds", "POST /orders/{id}", "/users/:id", "<int:id>",
r"/items/(?P<sku>[A-Z0-9-]+)"): a parameter or regex segment in the route
matches any value, so /orders/ord_1/refunds matches /orders/{id}/refunds; a
literal cut short by concatenation ("/orders/" + id) matches as a prefix; a
route may match the tail of the path when the head's segments appear in the
source (a mount prefix). When the test names the method and the route's line
does too (the Go "POST /x" pattern, a ("POST", r"/x") table, router.post,
methods=["POST"]), they must agree, so DELETE on a GET-only route is missing.

Usage: ref_check.py [--src DIR ...] <test file>...
Prints one line per missing reference and the counts; exits 1 on a missing
reference, on zero test files, or on zero references. Zero references is a
gate that checked nothing, so it never passes: a batch of pure unit tests
with no ids, names or routes reports the type check as its only gate. A
test that calls an unknown route on purpose (a 404 or 405 check) carries
`ref_check: absent` in a comment on that line; it is counted apart, and
fails if the source does serve the route.
"""

import argparse
import os
import re
import sys

SKIP_DIRS = {
    ".git",
    "node_modules",
    "dist",
    "build",
    ".next",
    "out",
    "coverage",
    ".venv",
    "venv",
    "__pycache__",
    "e2e",
    "tests",
    "test",
    "__tests__",
    "androidTest",
    "UITests",
    ".maestro",
    "playwright-report",
    "test-results",
    ".scratch",
    "docs",
}
SRC_EXT = {
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".mjs",
    ".vue",
    ".svelte",
    ".html",
    ".py",
    ".go",
    ".kt",
    ".java",
    ".xml",
    ".swift",
    ".dart",
    ".json",
    ".yaml",
    ".yml",
    ".strings",
    ".arb",
    ".po",
}

# A test that calls an unknown route on purpose (a 404 or 405 check) says so
# on that line: `// ref_check: absent` or `# ref_check: absent`.
ABSENT = "ref_check: absent"
METHODS = ("GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS")
Q = r"""(['"`])((?:(?!\1).){1,200})\1"""
PATTERNS = {
    "id": [
        r"getByTestId\(\s*" + Q,
        r"data-testid=\\?['\"]([^'\"\\]+)",
        r"withId\(\s*R\.id\.(\w+)",
        r"\.(?:buttons|textFields|staticTexts|otherElements|cells|images|switches)\[\s*"
        + Q
        + r"\s*\]",
        r"onNodeWithTag\(\s*" + Q,
    ],
    "name": [
        r"getByRole\([^)]*?name:\s*" + Q,
        r"getBy(?:Text|Label|Placeholder|Title|AltText)\(\s*" + Q,
        r"onNodeWithText\(\s*" + Q,
        r"withText\(\s*" + Q,
    ],
}
# Maestro flows name elements as YAML keys; in code the same shape is test data
# (a fixture's id: field), so these apply to .yaml and .yml files only.
YAML_PATTERNS = {"id": [r"^\s*-?\s*id:\s*" + Q], "name": [r"^\s*-?\s*tapOn:\s*" + Q]}
# Path references carry a method when the call names one. Each pattern has
# the named group p (the quoted path body) and optionally m or m2 (method).
QP = r"""(?P<q>['"`])(?P<p>(?:(?!(?P=q)).){1,200})(?P=q)"""
PATH_PATTERNS = [
    r"\.goto\(\s*" + QP,
    r"\b(?:request|client|api|http|ac|async_client|test_client)\.(?P<m>get|post|put|patch|delete)\(\s*"
    + QP,
    # httptest.NewRequest(M, "/x"), http.NewRequestWithContext(ctx, M, "/x"),
    # and any helper whose arguments give a method and then a path.
    r"(?:\bhttp\.Method(?P<m>[A-Z][a-z]+)|['\"](?P<m2>"
    + "|".join(METHODS)
    + r")['\"])\s*,\s*"
    + QP,
]
PARAM_SEG = re.compile(
    r"^(\{[^}]*\}|:\w+\??|<[^>]*>|\[[^\]]*\]|\*\w*|.*[()\\+?^$|].*)$"
)
ID_LIKE = re.compile(
    r"^(\d+|[0-9a-f-]{8,}|:\w+|\{\w+\}|\[\w+\]|<\w+>|\$\{[^}]+\})$", re.I
)
ROUTE_LIT = re.compile(
    r"""(['"`])(?:(?P<m>""" + "|".join(METHODS) + r""")\s+)?(?P<p>/[^'"`\s]*)\1"""
)


def value(m):
    """The captured literal: the quoted body when the pattern used Q, else group 1."""
    groups = [g for g in m.groups() if g is not None]
    if len(groups) >= 2 and groups[0] in ("'", '"', "`"):
        return groups[1]
    return groups[0] if groups else ""


def extract(text, yaml=False):
    """(kind, value, method) triples; method is None when the test does not say."""
    refs = []
    kinds = {k: PATTERNS[k] + (YAML_PATTERNS[k] if yaml else []) for k in PATTERNS}
    for kind, pats in kinds.items():
        for p in pats:
            for m in re.finditer(p, text, re.M):
                v = value(m)
                if not v or "${" in v:
                    continue  # a template literal is data from the builder, not a literal to find
                refs.append((kind, v, None))
    for p in PATH_PATTERNS:
        for m in re.finditer(p, text, re.M):
            d = m.groupdict()
            meth = (d.get("m") or d.get("m2") or "").upper() or None
            v = re.split(r"[?#]", m.group("p"), maxsplit=1)[0]
            if not v.startswith("/") and "://" in v:
                v = "/" + v.split("://", 1)[1].split("/", 1)[-1]
            if not v.startswith("/"):
                continue
            v = v.split("${", 1)[0]  # a template literal: its static head
            eol = text.find("\n", m.end())
            line = text[text.rfind("\n", 0, m.start()) + 1 : eol if eol >= 0 else None]
            if ABSENT in line:
                meth = (meth or "") + ABSENT  # a deliberate unknown route, counted apart
            refs.append(("path", v, meth))
    return refs


def source_files(dirs):
    for d in dirs:
        if os.path.isfile(d):
            yield d
            continue
        for root, subdirs, files in os.walk(d):
            subdirs[:] = [
                s for s in subdirs if s not in SKIP_DIRS and not s.startswith(".")
            ]
            for f in files:
                if os.path.splitext(f)[1] in SRC_EXT and not re.search(
                    r"(_test\.go|\.test\.|\.spec\.|^test_)", f
                ):
                    yield os.path.join(root, f)


def source_text(dirs):
    chunks = []
    for f in source_files(dirs):
        try:
            with open(f, encoding="utf-8", errors="ignore") as fh:
                chunks.append(fh.read())
        except OSError:
            pass
    return "\n".join(chunks)


def line_methods(line, lit_method):
    """The methods a routing line names, or None when it names none."""
    if lit_method:
        return {lit_method}
    found = set(re.findall(r"""['"](""" + "|".join(METHODS) + r""")['"]""", line))
    found |= {
        x.upper()
        for x in re.findall(r"\.(get|post|put|patch|delete|head|options)\s*\(", line)
    }
    found |= {x.upper() for x in re.findall(r"\bhttp\.Method([A-Z][a-z]+)", line)}
    return found or None


def routes(src_lines):
    """(segments, methods) for every quoted literal in the source that starts with /."""
    out = []
    for line in src_lines:
        for m in ROUTE_LIT.finditer(line):
            segs = [s for s in m.group("p").strip("/").split("/") if s]
            if segs:
                out.append((segs, line_methods(line, m.group("m"))))
    return out


def seg_match(test_seg, route_seg):
    return (
        test_seg == route_seg
        or bool(PARAM_SEG.match(route_seg))
        or bool(ID_LIKE.match(test_seg))
    )


def path_found(path, method, route_list, src):
    segs = [s for s in path.strip("/").split("/") if s]
    if not segs:
        return True  # "/": nothing literal to find
    prefix_only = path.endswith("/")  # "/orders/" + id: the rest is unknown
    for rsegs, rmethods in route_list:
        if method and rmethods and method not in rmethods:
            continue
        # the route is the whole path, or its tail after a mount prefix
        for start in range(len(segs)):
            tail = segs[start:]
            if len(tail) > len(rsegs) or (not prefix_only and len(tail) != len(rsegs)):
                continue
            if not all(seg_match(a, b) for a, b in zip(tail, rsegs)):
                continue
            head = segs[:start]
            if all(
                ID_LIKE.match(h) or re.search(r"['\"`]/" + re.escape(h), src)
                for h in head
            ):
                return True
    return False


TEMPLATE = re.compile(r"`([^`]*\$\{[^`]*)`")


def templates(src):
    """Each template literal with a ${...} part, as a regex its rendered text matches."""
    out = []
    for body in TEMPLATE.findall(src):
        parts = re.split(r"\$\{[^}]*\}", body)
        if sum(len(p.strip()) for p in parts) >= 3:
            out.append(re.compile(".+?".join(re.escape(p) for p in parts) + r"\Z", re.S))
    return out


def name_found(v, src, tpls):
    """A name appears as written, or is what a template literal in the source renders to."""
    return v in src or any(t.match(v) for t in tpls)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", action="append", default=[])
    ap.add_argument("tests", nargs="*")
    a = ap.parse_args()
    files = [t for t in a.tests if os.path.isfile(t)]
    problems = 0
    for t in a.tests:
        if os.path.isdir(t):
            problems += 1
            print(f"problem: {t}: not a test file (a second source directory needs its own --src)")
        elif not os.path.isfile(t):
            problems += 1
            print(f"problem: {t}: no such test file")
    if not files:
        print("test-refs: 0 test files, nothing checked", file=sys.stderr)
        return 1
    refs, seen = [], set()
    for f in files:
        with open(f, encoding="utf-8", errors="ignore") as fh:
            text = fh.read()
        for kind, v, meth in extract(text, f.endswith((".yaml", ".yml"))):
            if (kind, v, meth) not in seen:
                seen.add((kind, v, meth))
                refs.append((f, kind, v, meth))
    kinds = {k: sum(1 for r in refs if r[1] == k) for k in ("id", "name", "path")}
    if not refs:
        print(
            f"test-refs: {len(files)} test files, 0 references (ids, names, paths), "
            "nothing checked; this gate did not pass, the type check is the only gate",
            file=sys.stderr,
        )
        return 1
    src = source_text(a.src or ["."])
    route_list = routes(src.split("\n"))
    tpls = templates(src)
    missing, absent = [], 0
    for f, kind, v, meth in refs:
        if meth and meth.endswith(ABSENT):
            meth = meth[: -len(ABSENT)] or None
            label = f"{meth} {v}" if meth else v
            if path_found(v, meth, route_list, src):
                missing.append(f"{f}: path {label!r} is marked absent but the source serves it")
            else:
                absent += 1
            continue
        if kind == "path":
            ok = path_found(v, meth, route_list, src)
            label = f"{meth} {v}" if meth else v
        elif kind == "name":
            ok = name_found(v, src, tpls)
            label = v
        else:
            ok = v in src
            label = v
        if not ok:
            missing.append(f"{f}: {kind} {label!r} is not in the source")
    for m in missing:
        print(f"missing: {m}")
    print(
        f"test-refs: {len(files)} test files, {len(refs)} references "
        f"(ids {kinds['id']}, names {kinds['name']}, paths {kinds['path']}), {len(missing)} missing"
        + (f", {absent} declared absent (unknown-route tests)" if absent else "")
    )
    return 1 if missing or problems else 0


if __name__ == "__main__":
    sys.exit(main())
