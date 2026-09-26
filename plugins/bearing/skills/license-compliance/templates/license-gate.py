#!/usr/bin/env python3
"""Licence gate over a CycloneDX JSON SBOM and a flat policy file.

    python3 scripts/license-gate.py <sbom.cdx.json> <license-policy.yml> [--allow-unknown]

Prints "licenses: N components, allowed A, denied D, unknown U" and
exits 1 when N is 0, when D is over 0, or when U is over 0 without
--allow-unknown. Needs Python 3 only; the policy is parsed by hand so
PyYAML is not required (two flat lists and an exceptions map)."""

import json
import re
import sys


def read_policy(path):
    allow, deny, exceptions, section = set(), set(), {}, None
    for raw in open(path, encoding="utf-8"):
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        if not line.startswith(" ") and line.endswith(":"):
            section = line[:-1].strip()
            continue
        m = re.match(r"\s*-\s*(.+?)\s*$", line)
        if m and section == "allow":
            allow.add(m.group(1))
        elif m and section == "deny":
            deny.add(m.group(1))
        elif section == "exceptions":
            m2 = re.match(r"\s*-?\s*([^:]+?)\s*:\s*(.+)$", line)
            if m2:
                exceptions[m2.group(1)] = m2.group(2)
    return allow, deny, exceptions


def component_licenses(component):
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


def verdict(expr, allow, deny):
    """allowed | denied | unknown for one SPDX expression."""
    expr = expr.strip().strip("()")
    if " OR " in expr:
        parts = [verdict(p, allow, deny) for p in expr.split(" OR ")]
        return (
            "allowed"
            if "allowed" in parts
            else ("denied" if "denied" in parts else "unknown")
        )
    if " AND " in expr:
        parts = [verdict(p, allow, deny) for p in expr.split(" AND ")]
        return (
            "denied"
            if "denied" in parts
            else ("unknown" if "unknown" in parts else "allowed")
        )
    if expr in deny:
        return "denied"
    if expr in allow:
        return "allowed"
    return "unknown"


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    allow_unknown = "--allow-unknown" in argv
    sbom = json.load(open(argv[1], encoding="utf-8"))
    allow, deny, exceptions = read_policy(argv[2])
    components = sbom.get("components", []) or []
    counts = {"allowed": 0, "denied": 0, "unknown": 0}
    rows = []
    for c in components:
        key = "%s@%s" % (c.get("name"), c.get("version"))
        ids = component_licenses(c)
        if key in exceptions or c.get("name") in exceptions:
            v = "allowed"
        elif not ids:
            v = "unknown"
        else:
            vs = [verdict(i, allow, deny) for i in ids]
            v = (
                "denied"
                if "denied" in vs
                else ("unknown" if "unknown" in vs else "allowed")
            )
        counts[v] += 1
        rows.append((key, ", ".join(ids) or "(none)", v))
    n = len(components)
    print(
        "licenses: %d components, allowed %d, denied %d, unknown %d"
        % (n, counts["allowed"], counts["denied"], counts["unknown"])
    )
    for key, lic, v in rows:
        if v != "allowed":
            print("  %s: %s %s" % (v, key, lic))
    if n == 0:
        print(
            "license-gate: 0 components in the SBOM; nothing checked", file=sys.stderr
        )
        return 1
    if counts["denied"] > 0:
        return 1
    if counts["unknown"] > 0 and not allow_unknown:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
