#!/usr/bin/env python3
"""Licence gate over a CycloneDX JSON SBOM or an npm lockfile (v2 or v3).

    python3 scripts/license-gate.py <sbom.cdx.json | package-lock.json> <license-policy.yml>
                                    [--allow-unknown] [--list]

Prints "licenses: N components (R runtime, D dev), allowed A, denied X,
unknown U" and exits 1 when N is 0, when a runtime component is denied, or
when a runtime component is unknown (unless --allow-unknown). Dev-scope
components are judged too; they fail only when the policy says `dev: check`.
--list prints one row per component (for the inventory file).

Scope: an npm lockfile entry with "dev": true is dev; everything else,
including "devOptional", "optional" and "peer", is runtime, because
`npm ci --omit=dev` still installs it. A package named in devDependencies
that a runtime package also requires has no dev flag and ships. In a
CycloneDX SBOM, scope "excluded" is dev; anything else is runtime.

Expressions: full SPDX grammar (parentheses, AND binds tighter than OR,
WITH, the "+" suffix). "A OR B" is allowed when either side is allowed;
"A AND B" is denied when either side is denied. "X WITH exc" takes the
verdict of the whole string when the policy lists it, else of X.
"UNLICENSED" (npm: no licence granted) and "SEE LICENSE IN ..." are
unknown: a person must read the terms. They are not "Unlicense".

Exceptions must name one version ("name@version: reason (owner, date)");
a bare name is refused, since it would exempt every future version.
Needs Python 3 only; the policy is parsed by hand (no PyYAML)."""

import json
import re
import sys

DEPRECATED = {
    "gpl-2.0": "gpl-2.0-only",
    "gpl-3.0": "gpl-3.0-only",
    "lgpl-2.1": "lgpl-2.1-only",
    "lgpl-3.0": "lgpl-3.0-only",
    "agpl-3.0": "agpl-3.0-only",
}


def read_policy(path):
    allow, deny, exceptions, dev, section = set(), set(), {}, "check", None
    for raw in open(path, encoding="utf-8"):
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        top = re.match(r"^(\w+):\s*(\S*)\s*$", line)
        if top:
            section = top.group(1)
            if section == "dev" and top.group(2):
                dev = top.group(2).strip("'\"")
            continue
        m = re.match(r"\s*-\s*(.+?)\s*$", line)
        if m and section == "allow":
            allow.add(m.group(1).strip("'\"").lower())
        elif m and section == "deny":
            deny.add(m.group(1).strip("'\"").lower())
        elif section == "exceptions":
            m2 = re.match(r"\s*-?\s*['\"]?(@?[^:'\"]+?)['\"]?\s*:\s*(.+)$", line)
            if m2:
                exceptions[m2.group(1).strip()] = m2.group(2).strip()
    if dev not in ("allow", "check"):
        raise SystemExit(
            "license-gate: policy dev: must be allow or check, got %r" % dev
        )
    return allow, deny, exceptions, dev


def parse(expr):
    """SPDX expression to a tree: ('or'|'and', [..]) or ('id', text)."""
    toks, pos = re.findall(r"\(|\)|[^\s()]+", expr), [0]

    def peek():
        return toks[pos[0]] if pos[0] < len(toks) else None

    def take():
        if pos[0] >= len(toks):
            raise ValueError("unexpected end in %r" % expr)
        pos[0] += 1
        return toks[pos[0] - 1]

    def atom():
        t = take()
        if t == ")":
            raise ValueError("unexpected ) in %r" % expr)
        if t == "(":
            node = disj()
            if take() != ")":
                raise ValueError("unbalanced parentheses in %r" % expr)
            return node
        if peek() is not None and peek().upper() == "WITH":
            take()
            return ("id", "%s WITH %s" % (t, take()))
        return ("id", t)

    def conj():
        parts = [atom()]
        while peek() is not None and peek().upper() == "AND":
            take()
            parts.append(atom())
        return parts[0] if len(parts) == 1 else ("and", parts)

    def disj():
        parts = [conj()]
        while peek() is not None and peek().upper() == "OR":
            take()
            parts.append(conj())
        return parts[0] if len(parts) == 1 else ("or", parts)

    node = disj()
    if peek() is not None:
        raise ValueError("trailing tokens in %r" % expr)
    return node


def judge_id(text, allow, deny):
    whole = text.lower()
    if whole in deny:
        return "denied"
    if whole in allow:
        return "allowed"
    base = whole.split(" with ")[0]
    if base.endswith("+"):
        base = DEPRECATED.get(base[:-1], base[:-1]).replace("-only", "") + "-or-later"
    base = DEPRECATED.get(base, base)
    if base in deny:
        return "denied"
    if base in allow:
        return "allowed"
    return "unknown"


def judge(node, allow, deny):
    kind, body = node
    if kind == "id":
        return judge_id(body, allow, deny)
    vs = [judge(n, allow, deny) for n in body]
    if kind == "or":
        return (
            "allowed"
            if "allowed" in vs
            else ("unknown" if "unknown" in vs else "denied")
        )
    return "denied" if "denied" in vs else ("unknown" if "unknown" in vs else "allowed")


def verdict(expr, allow, deny):
    e = expr.strip()
    up = e.upper()
    if (
        not e
        or up in ("UNLICENSED", "NOASSERTION", "NONE")
        or up.startswith("SEE LICENSE")
    ):
        return "unknown"
    try:
        return judge(parse(e), allow, deny)
    except ValueError:
        return "unknown"


def lock_license(entry):
    lic = entry.get("license")
    if isinstance(lic, dict):
        lic = lic.get("type")
    if not lic and isinstance(entry.get("licenses"), list):
        names = [x.get("type") if isinstance(x, dict) else x for x in entry["licenses"]]
        lic = " OR ".join("(%s)" % n for n in names if n)
    return [lic] if lic else []


def from_lockfile(doc):
    rows = []
    for path, entry in (doc.get("packages") or {}).items():
        if not path or entry.get("link"):
            continue
        name = entry.get("name") or path.rsplit("node_modules/", 1)[-1]
        scope = "dev" if entry.get("dev") else "runtime"
        rows.append((name, entry.get("version", "?"), lock_license(entry), scope))
    return rows


def sbom_license(component):
    ids = []
    for entry in component.get("licenses", []) or []:
        if "expression" in entry:
            ids.append(entry["expression"])
        lic = entry.get("license") or {}
        if lic.get("id"):
            ids.append(lic["id"])
        elif lic.get("name"):
            ids.append(lic["name"])
    return ids


def from_sbom(doc):
    rows = []
    for c in doc.get("components", []) or []:
        scope = "dev" if c.get("scope") == "excluded" else "runtime"
        name = c.get("name")
        if c.get("group"):
            name = "%s/%s" % (c["group"], name)
        rows.append((name, c.get("version", "?"), sbom_license(c), scope))
    return rows


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        print(__doc__)
        return 2
    allow_unknown, show_all = "--allow-unknown" in argv, "--list" in argv
    try:
        doc = json.load(open(args[0], encoding="utf-8"))
    except (OSError, ValueError) as err:
        print(
            "license-gate: cannot read %s: %s; 0 components checked" % (args[0], err),
            file=sys.stderr,
        )
        return 1
    allow, deny, exceptions, dev = read_policy(args[1])
    if "packages" in doc:
        rows, source = (
            from_lockfile(doc),
            "npm lockfile v%s" % doc.get("lockfileVersion", "?"),
        )
    elif "components" in doc or doc.get("bomFormat") == "CycloneDX":
        rows, source = from_sbom(doc), "CycloneDX SBOM"
    else:
        print(
            "license-gate: %s is neither a CycloneDX SBOM nor an npm v2/v3 lockfile "
            "(a v1 lockfile carries no licences); 0 components checked" % args[0],
            file=sys.stderr,
        )
        return 1

    for key in exceptions:
        if "@" not in key.lstrip("@"):
            print(
                "  refused exception %r: name one version (name@version)" % key,
                file=sys.stderr,
            )
    counts = {"allowed": 0, "denied": 0, "unknown": 0}
    failing, out, used = 0, [], set()
    for name, version, lics, scope in rows:
        key = "%s@%s" % (name, version)
        expr = (
            " AND ".join("(%s)" % x for x in lics)
            if len(lics) > 1
            else (lics[0] if lics else "")
        )
        v = verdict(expr, allow, deny)
        shown = v
        if v != "allowed" and key in exceptions:
            used.add(key)
            v, shown = "allowed", "exception"
        counts[v] += 1
        fails = (
            v != "allowed"
            and (scope == "runtime" or dev == "check")
            and not (v == "unknown" and allow_unknown)
        )
        failing += fails
        out.append((key, expr or "(none)", shown, scope, fails))

    n = len(rows)
    runtime = sum(1 for r in rows if r[3] == "runtime")
    print(
        "licenses: %d components (%d runtime, %d dev) from %s, allowed %d, denied %d, unknown %d; policy dev: %s"
        % (
            n,
            runtime,
            n - runtime,
            source,
            counts["allowed"],
            counts["denied"],
            counts["unknown"],
            dev,
        )
    )
    for key, expr, shown, scope, fails in out:
        if show_all or shown != "allowed":
            print(
                "  %-9s %-7s %s  %s%s"
                % (shown, scope, key, expr, "  FAIL" if fails else "")
            )
    for key in sorted(set(exceptions) - used):
        print(
            "  stale exception (no failing component matches): %s" % key,
            file=sys.stderr,
        )
    if n == 0:
        print(
            "license-gate: 0 components; wrong file or empty lockfile, nothing checked",
            file=sys.stderr,
        )
        return 1
    print("license-gate: %d failing" % failing)
    return 1 if failing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
