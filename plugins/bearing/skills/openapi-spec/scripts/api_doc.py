#!/usr/bin/env python3
"""api_doc: write docs/api/API.md, the human-readable API design, from api/openapi.yaml.

The spec is the contract; this is the page a reviewer, a client developer or
a tester reads first. It is generated so the two cannot disagree:

  header       title and version; Style, Base path and Versioning; an
               Authentication paragraph; the error code table (code, HTTP
               status, meaning) from x-error-codes on the error envelope.
  Conventions  numbered, each with its reason: "N. <rule>. Why: <reason>."
               lines from the style reference (--style), then the spec's
               own x-conventions ([{rule, why}]).
  per-status   an operation may narrow the codes behind a status with
  codes        x-error-codes: {"409": [invoice_closed]}; a shared response
               may carry x-error-codes: [code, ...]; otherwise every code
               the envelope declares for that status is listed.
  resources    one section per tag: its description as the purpose,
               "Serves US-..." from the operations' x-story-ids, and a
               table Method | Path | Does | Auth | Success | Errors, then
               the idempotency note for each write.

Reads YAML with PyYAML (run it as `uv run --quiet --with pyyaml==6.0.3 python
api_doc.py ...`); a spec written as JSON also loads without PyYAML.

Usage: api_doc.py --spec api/openapi.yaml [--style api-style.md] [--out docs/api/API.md]
Prints the findings (an operation with no x-story-ids, a create POST with no
Idempotency-Key, a PATCH not documented idempotent, an error status with no
declared code) and one counts line:
  api-doc: N operations in N resources, N paths, N error codes, N conventions, N stories, N findings -> <out>
Exits 1 on zero operations, zero conventions from a given --style, or an
unreadable spec; the document is not written then. Findings do not fail the
run; the skill reports them.
"""

import argparse
import json
import os
import re
import sys
from urllib.parse import urlparse

METHODS = ("get", "post", "put", "patch", "delete")


def load(path):
    text = open(path, encoding="utf-8").read()
    try:
        import yaml  # noqa: PLC0415

        return yaml.safe_load(text)
    except ImportError:
        try:
            return json.loads(text)
        except ValueError:
            sys.exit(
                "api-doc: PyYAML is not installed and the spec is not JSON; run with "
                "`uv run --quiet --with pyyaml==6.0.3 python api_doc.py ...`"
            )


def resolve(spec, node, depth=0):
    """Follow a local $ref (#/a/b) to its target; other nodes come back as they are."""
    while isinstance(node, dict) and "$ref" in node and depth < 20:
        ref = node["$ref"]
        if not ref.startswith("#/"):
            return node
        cur = spec
        for part in ref[2:].split("/"):
            part = part.replace("~1", "/").replace("~0", "~")
            cur = cur.get(part, {}) if isinstance(cur, dict) else {}
        node, depth = cur, depth + 1
    return node if isinstance(node, dict) else {}


def cell(text):
    """One table cell: single line, pipes escaped."""
    return re.sub(r"\s+", " ", str(text or "")).strip().replace("|", "\\|")


def conventions_from(style):
    out = []
    for line in open(style, encoding="utf-8"):
        m = re.match(r"^\s*\d+\.\s+(.*?)\s+Why:\s+(.*\S)\s*$", line)
        if m:
            out.append((m.group(1).rstrip(), m.group(2)))
    return out


def params_of(spec, path_item, op):
    out = []
    for p in (path_item.get("parameters") or []) + (op.get("parameters") or []):
        p = resolve(spec, p)
        if p:
            out.append(p)
    return out


def auth_of(spec, op, global_sec):
    sec = op.get("security", global_sec)
    if sec is None:
        return "unstated"
    if sec == [] or all(not s for s in sec):
        return "none"
    names = []
    for req in sec:
        for name, scopes in (req or {}).items():
            names.append(name + (" (" + ", ".join(scopes) + ")" if scopes else ""))
    return " or ".join(names) or "none"


def codes_by_status(error_codes):
    by = {}
    for e in error_codes:
        by.setdefault(str(e.get("status")), []).append(str(e.get("code")))
    return by


def describe_responses(spec, op, by_status, findings, where):
    ok, errs = [], []
    for status, resp in sorted(
        (op.get("responses") or {}).items(), key=lambda kv: str(kv[0])
    ):
        status = str(status)
        r = resolve(spec, resp)
        desc = r.get("description", "")
        if status.startswith("2") or status.startswith("3"):
            ok.append(f"{status} {desc}".strip())
            continue
        # Most specific first: the operation's own map, the response's list,
        # then every code the envelope declares for this status.
        op_codes = op.get("x-error-codes")
        codes = (
            (op_codes.get(status) if isinstance(op_codes, dict) else None)
            or r.get("x-error-codes")
            or by_status.get(status, [])
        )
        if codes:
            errs.append(", ".join(f"{status} {c}" for c in codes))
        else:
            errs.append(f"{status} ({desc})" if desc else status)
            if status != "default" and by_status:
                findings.append(
                    f"{where}: {status} has no declared error code in x-error-codes"
                )
    return "; ".join(ok) or "unstated", ", ".join(errs) or "none"


def idempotency_note(method, path, op, params, findings, where):
    header = next(
        (
            p
            for p in params
            if p.get("in") == "header"
            and str(p.get("name", "")).lower() == "idempotency-key"
        ),
        None,
    )
    m = method.upper()
    if header is not None:
        req = "required" if header.get("required") else "optional"
        detail = cell(header.get("description", ""))
        return f"`{m} {path}`: Idempotency-Key {req}." + (
            f" {detail}" if detail else ""
        )
    if m == "POST":
        statuses = [str(s) for s in (op.get("responses") or {})]
        if "201" in statuses:
            findings.append(
                f"{where}: creates (201) with no Idempotency-Key; a retried request makes a second record"
            )
            return f"`{m} {path}`: not idempotent, no Idempotency-Key (finding)."
        return f"`{m} {path}`: not idempotent; a retry repeats the action."
    if m in ("PUT", "DELETE"):
        return f"`{m} {path}`: idempotent by definition; a retry has the same effect."
    if m == "PATCH":
        if op.get("x-idempotent") is True:
            return f"`{m} {path}`: documented idempotent (x-idempotent)."
        findings.append(
            f"{where}: PATCH not documented as idempotent (set x-idempotent: true or do not offer it)"
        )
        return f"`{m} {path}`: not documented as idempotent (finding)."
    return ""


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--spec", default="api/openapi.yaml")
    ap.add_argument("--style")
    ap.add_argument("--out", default="docs/api/API.md")
    a = ap.parse_args()
    if not os.path.isfile(a.spec):
        print(f"api-doc: 0 operations, nothing written (no spec at {a.spec})")
        return 1
    spec = load(a.spec)
    if not isinstance(spec, dict):
        print(
            f"api-doc: 0 operations, nothing written ({a.spec} is empty or not a mapping)"
        )
        return 1

    info = spec.get("info") or {}
    paths = spec.get("paths") or {}
    global_sec = spec.get("security")
    schemes = (spec.get("components") or {}).get("securitySchemes") or {}
    error_codes = []
    for name, schema in ((spec.get("components") or {}).get("schemas") or {}).items():
        if isinstance(schema, dict) and schema.get("x-error-codes"):
            error_codes.extend(schema["x-error-codes"])
    by_status = codes_by_status(error_codes)

    conventions = []
    if a.style:
        if not os.path.isfile(a.style):
            print(
                f"api-doc: 0 conventions, nothing written (no style reference at {a.style})"
            )
            return 1
        conventions = conventions_from(a.style)
        if not conventions:
            print(
                f"api-doc: 0 conventions in {a.style} (want lines 'N. <rule>. Why: <reason>.'), nothing written"
            )
            return 1
    for c in spec.get("x-conventions") or info.get("x-conventions") or []:
        if isinstance(c, dict) and c.get("rule"):
            conventions.append(
                (str(c["rule"]).rstrip("."), str(c.get("why", "unstated")))
            )

    findings = []
    tags = {t.get("name"): t for t in (spec.get("tags") or []) if isinstance(t, dict)}
    order = [t for t in tags]
    groups = {}
    n_ops = 0
    for path, item in paths.items():
        if not isinstance(item, dict):
            continue
        for method in METHODS:
            op = item.get(method)
            if not isinstance(op, dict):
                continue
            n_ops += 1
            tag = (op.get("tags") or ["untagged"])[0]
            if tag not in order:
                order.append(tag)
            groups.setdefault(tag, []).append((method, path, item, op))

    if n_ops == 0:
        print(f"api-doc: 0 operations in {a.spec}, nothing written")
        return 1

    servers = spec.get("servers") or [{}]
    base = urlparse(str(servers[0].get("url", ""))).path or "/"
    uses_version_header = any(
        str(p.get("name", "")).lower() == "x-api-version"
        for _, _, item, op in (g for gs in groups.values() for g in gs)
        for p in params_of(spec, item, op)
    )
    style = (
        info.get("x-api-style")
        or f"REST over HTTPS, JSON, described by OpenAPI {spec.get('openapi', '3')} (derived: add info.x-api-style)"
    )
    versioning = info.get("x-versioning") or (
        f"Major version in the path ({base})"
        + (
            "; dated changes inside a major in X-API-Version"
            if uses_version_header
            else ""
        )
        + " (derived: add info.x-versioning)"
    )
    if info.get("x-authentication"):
        auth = str(info["x-authentication"])
    else:
        parts = []
        for name, s in schemes.items():
            s = resolve(spec, s)
            kind = s.get("scheme") or s.get("type", "")
            fmt = f" ({s['bearerFormat']})" if s.get("bearerFormat") else ""
            parts.append(
                f"`{name}`: {kind}{fmt}"
                + (f", {s['description']}" if s.get("description") else "")
            )
        auth = (
            ("Schemes: " + "; ".join(parts) + ". ")
            if parts
            else "No security scheme is declared. "
        )
        auth += (
            "Global requirement: "
            + (auth_of(spec, {}, global_sec))
            + ". (Derived: add info.x-authentication.)"
        )
    public = [
        f"{m.upper()} {p}"
        for gs in groups.values()
        for (m, p, _, op) in gs
        if auth_of(spec, op, global_sec) == "none"
    ]

    lines = [f"# API: {info.get('title', 'untitled')} v{info.get('version', '?')}", ""]
    lines.append(
        f"Generated from `{a.spec}` by openapi-spec (scripts/api_doc.py). Edit the spec, not this file."
    )
    lines.append("")
    lines.append(
        f"**Style:** {cell(style)} · **Base path:** `{base}` · **Versioning:** {cell(versioning)}"
    )
    lines.append("")
    lines.append(
        f"**Authentication.** {cell(auth)}"
        + (f" Public operations: {', '.join(public)}." if public else "")
    )
    lines.append("")
    lines.append(
        "**Errors.** Every 4xx and 5xx returns the error envelope; clients switch on `code`."
    )
    lines.append("")
    if error_codes:
        lines += ["| Code | HTTP status | Meaning |", "| --- | --- | --- |"]
        for e in sorted(
            error_codes, key=lambda e: (str(e.get("status")), str(e.get("code")))
        ):
            lines.append(
                f"| `{cell(e.get('code'))}` | {cell(e.get('status'))} | {cell(e.get('meaning'))} |"
            )
    else:
        lines.append(
            "No error codes are declared (add x-error-codes to the error envelope schema)."
        )
        findings.append(
            "spec: no x-error-codes on the error envelope; the code table is empty"
        )
    lines.append("")

    if conventions:
        lines += ["## Conventions", ""]
        for i, (rule, why) in enumerate(conventions, 1):
            lines.append(f"{i}. {rule.rstrip('.')}. Why: {why}")
        lines.append("")

    all_stories = set()
    for tag in order:
        ops = groups.get(tag)
        if not ops:
            continue
        t = tags.get(tag, {})
        lines += [f"## {tag}", ""]
        lines += [
            cell(t.get("description")) or "No description (add one to the tag).",
            "",
        ]
        stories = []
        for s in list(t.get("x-story-ids") or []) + [
            s for (_, _, _, op) in ops for s in (op.get("x-story-ids") or [])
        ]:
            if s not in stories:
                stories.append(str(s))
        all_stories.update(stories)
        lines += [
            f"Serves {', '.join(stories)}."
            if stories
            else "Serves: unnumbered (no x-story-ids).",
            "",
        ]
        lines += [
            "| Method | Path | Does | Auth | Success | Errors |",
            "| --- | --- | --- | --- | --- | --- |",
        ]
        notes = []
        for method, path, item, op in ops:
            where = f"{method.upper()} {path}"
            if not op.get("x-story-ids"):
                findings.append(f"{where}: no x-story-ids")
            does = (
                op.get("summary")
                or op.get("description")
                or op.get("operationId")
                or ""
            )
            if op.get("deprecated"):
                does = f"Deprecated. {does}"
            success, errors = describe_responses(spec, op, by_status, findings, where)
            lines.append(
                f"| {method.upper()} | `{path}` | {cell(does)} | {cell(auth_of(spec, op, global_sec))} | {cell(success)} | {cell(errors)} |"
            )
            if method != "get":
                note = idempotency_note(
                    method, path, op, params_of(spec, item, op), findings, where
                )
                if note:
                    notes.append(note)
        lines.append("")
        if notes:
            lines += ["Idempotency:", ""] + [f"- {n}" for n in notes] + [""]

    if findings:
        lines += [
            "## Findings",
            "",
            "Raised by the generator; each is a change to the spec or a decision to record.",
            "",
        ]
        lines += [f"- {cell(f)}" for f in findings] + [""]

    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines).rstrip() + "\n")
    for f in findings:
        print(f)
    n_res = sum(1 for t in order if groups.get(t))
    print(
        f"api-doc: {n_ops} operations in {n_res} resources, {len(paths)} paths, "
        f"{len(error_codes)} error codes, {len(conventions)} conventions, {len(all_stories)} stories, "
        f"{len(findings)} findings -> {a.out}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
