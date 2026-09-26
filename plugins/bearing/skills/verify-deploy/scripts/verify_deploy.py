#!/usr/bin/env python3
"""verify_deploy: check one deployed environment, in order, after the engineer
deploys it. It reads; it never deploys, rolls back or writes to a server.

  - File: docs/environments.md (or --file). The environment is the "## <env>"
    section; HTML comments are ignored. Two tables in the section are read:
      a "| Key | Value |" table with the rows Product URL, API base URL,
        Health path, Readiness path, Version path, Version field, Owner,
        Rollback and Synthetic suite;
      a "| Smoke check | Base | Path | Expect | Contains |" table, one row per
        GET: Base is product or api, Expect the status, Contains optional
        text the body must hold.
    An empty cell, "-", "none", "n/a" or an unfilled "<placeholder>" means not
    set. A URL carrying credentials (user:pass@host) stops the run: the file
    is committed and holds no secrets.
  - Checks, in order: readiness, health, version, each smoke check. Health,
    readiness and version use the API base URL, else the product URL.
    Readiness and health expect 200. Version expects 200 and the field
    (json:<dotted.path> or header:<Name>); with --expect, a commit (7 to 40
    hex characters) matches when one is a prefix of the other and the shorter
    has at least 7 characters, and anything else (a tag) matches exactly.
    --expect with no version path defined is a failed check, since the
    version could not be compared.
  - HTTP: GET only, no body, no credentials. At most 3 redirects. --timeout
    seconds per request. --retries extra attempts, only on connection errors
    and on 502, 503 and 504, with a short backoff.
  - Report: <out>/verify-<env>-<UTC YYYY-MM-DDTHHMMSSZ>.md with the table
    (check, URL, expected, got, ms, result), the verdict and, on a failure,
    the rollback sentence from the file for the engineer to act on.
  - Verdict: pass (every check passed), fail (a host answered and a check
    failed) or unverified (no check got an answer: every one was a
    connection error, so the run says nothing about the deploy; DNS, VPN,
    the network or a sandbox allow-list is the first suspect, and the
    rollback sentence is held back until a host answers). A reserved
    hostname (.invalid, .example, example.com) is named, since it never
    resolves.
  - A python3 without the ssl module cannot check https: the run stops
    before any request and writes no report, since every row would describe
    the local interpreter and not the deploy.

Usage: verify_deploy.py --env <env> [--expect <commit|tag>]
         [--file docs/environments.md] [--out docs/releases/]
         [--timeout 10] [--retries 2]
Prints one line per check, "reach: U of N checks got no answer" when any
check got a connection error, and last "verify: N checks, F failed (env
<env>, deployed <version or unknown>)". Exits 1 when F > 0, when the file or
the environment is missing, when the environment defines zero checks or when
https cannot be checked from this python3; exits 2 on a usage error.
"""

import argparse
import datetime
import json
import os
import re
import socket
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

MAX_REDIRECTS = 3
RETRY_STATUS = (502, 503, 504)
BODY_LIMIT = 1024 * 1024  # enough for a smoke page; a check never needs more
UNSET = ("", "-", "none", "n/a")
COMMIT = re.compile(r"^[0-9a-fA-F]{7,40}$")
USER_AGENT = "bearing-verify-deploy/1"
# reserved names (RFC 2606, RFC 6761) that never resolve on a real network
RESERVED = re.compile(r"(^|\.)(invalid|example|example\.(com|net|org))$", re.I)


class Redirects(urllib.request.HTTPRedirectHandler):
    max_redirections = MAX_REDIRECTS


OPENER = urllib.request.build_opener(Redirects)

try:  # a python3 built without OpenSSL cannot check https; say so, not "unknown url type"
    import ssl  # noqa: F401

    HAS_SSL = True
except ImportError:
    HAS_SSL = False


def value(cell):
    """A table cell, or "" when it is empty, a dash, none or a placeholder."""
    cell = cell.strip().strip("`").strip()
    # a whole-cell "<...>" is an unfilled placeholder; "<title>" inside text is not
    if cell.lower() in UNSET or re.match(r"^<[^<>]*>$", cell):
        return ""
    return cell


def rows(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def parse(text, env):
    """(settings dict, smoke list) for the env, or None when it has no section."""
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    text = re.sub(r"^```.*?^```", "", text, flags=re.M | re.S)
    section, found = [], False
    for line in text.split("\n"):
        h = re.match(r"^##\s+(\S+)", line)
        if h and not line.startswith("###"):
            name = h.group(1).strip("`:").lower()
            if found:
                break
            found = name == env.lower()
            continue
        if found:
            section.append(line)
    if not found:
        return None
    settings, smoke, table = {}, [], None
    for line in section:
        if not line.strip().startswith("|"):
            table = None
            continue
        cells = rows(line)
        if all(re.match(r"^:?-{3,}:?$", c) for c in cells if c):
            continue
        head = [c.lower() for c in cells]
        if head[:2] == ["key", "value"]:
            table = "kv"
            continue
        if head and head[0] == "smoke check":
            table = "smoke"
            continue
        if table == "kv" and len(cells) >= 2:
            key = re.sub(r"[^a-z]+", "_", cells[0].lower()).strip("_")
            settings[key] = value(cells[1])
        elif table == "smoke" and len(cells) >= 4:
            name, base, path, expect = (value(c) for c in cells[:4])
            contains = value(cells[4]) if len(cells) > 4 else ""
            if path:  # a row whose path is not set is a check not run
                smoke.append(
                    {
                        "name": name or path,
                        "base": base.lower(),
                        "path": path,
                        "expect": expect,
                        "contains": contains,
                    }
                )
    return settings, smoke


def join(base, path):
    if re.match(r"^https?://", path):
        return path
    if not base:
        return ""
    return base.rstrip("/") + "/" + path.lstrip("/")


def fetch(url, timeout, retries):
    """(status or None, headers, body text, ms, error text)."""
    attempt, start = 0, time.monotonic()
    while True:
        req = urllib.request.Request(
            url, method="GET", headers={"User-Agent": USER_AGENT}
        )
        status, headers, body, err = None, {}, "", ""
        try:
            with OPENER.open(req, timeout=timeout) as r:
                status, headers = r.status, r.headers
                body = r.read(BODY_LIMIT).decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if 300 <= e.code < 400:
                err = f"more than {MAX_REDIRECTS} redirects"
            else:
                status, headers = e.code, e.headers
                try:
                    body = e.read(BODY_LIMIT).decode("utf-8", "replace")
                except OSError:
                    body = ""
        except (
            urllib.error.URLError,
            socket.timeout,
            TimeoutError,
            ConnectionError,
            OSError,
        ) as e:
            reason = getattr(e, "reason", e)
            err = f"connection error: {reason}"
        again = err.startswith("connection error") or status in RETRY_STATUS
        if again and attempt < retries:
            attempt += 1
            time.sleep(0.5 * attempt)
            continue
        ms = int((time.monotonic() - start) * 1000)
        return status, headers, body, ms, err


def field_of(spec, headers, body):
    """The deployed version read by a json:<path> or header:<Name> spec."""
    kind, _, name = spec.partition(":")
    if not name:
        kind, name = "json", spec
    if kind.strip().lower() == "header":
        return (headers.get(name.strip()) or "").strip() if headers else ""
    try:
        data = json.loads(body)
    except ValueError:
        return ""
    for part in name.strip().split("."):
        if not isinstance(data, dict) or part not in data:
            return ""
        data = data[part]
    return "" if data is None or isinstance(data, (dict, list)) else str(data).strip()


def matches(expect, got):
    if COMMIT.match(expect) and COMMIT.match(got):
        short = min(len(expect), len(got))
        return short >= 7 and expect[:short].lower() == got[:short].lower()
    return expect == got


def cell(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


def main():
    ap = argparse.ArgumentParser(
        description="Verify a deployed environment from docs/environments.md."
    )
    ap.add_argument("--env", required=True)
    ap.add_argument("--expect", default="")
    ap.add_argument("--file", default="docs/environments.md")
    ap.add_argument("--out", default="docs/releases/")
    ap.add_argument("--timeout", type=float, default=10)
    ap.add_argument("--retries", type=int, default=2)
    a = ap.parse_args()
    if a.timeout <= 0 or a.retries < 0 or not a.env.strip():
        ap.print_usage(sys.stderr)
        print(
            "verify_deploy: --timeout must be above 0, --retries 0 or more, --env not empty",
            file=sys.stderr,
        )
        return 2
    env, expect = a.env.strip(), a.expect.strip()

    def summary(n, f, deployed):
        print(
            f"verify: {n} checks, {f} failed (env {env}, deployed {deployed or 'unknown'})"
        )

    if not os.path.isfile(a.file):
        print(
            f"verify_deploy: {a.file} not found; copy the verify-deploy template and fill the URLs",
            file=sys.stderr,
        )
        summary(0, 0, "")
        return 1
    parsed = parse(open(a.file, encoding="utf-8").read(), env)
    if parsed is None:
        print(f"verify_deploy: no '## {env}' section in {a.file}", file=sys.stderr)
        summary(0, 0, "")
        return 1
    s, smoke = parsed
    product, api = s.get("product_url", ""), s.get("api_base_url", "")
    for label, url in (("Product URL", product), ("API base URL", api)):
        if url and urllib.parse.urlsplit(url).scheme not in ("http", "https"):
            print(
                f"verify_deploy: {label} for {env} is not an http or https URL: {url}",
                file=sys.stderr,
            )
            summary(0, 0, "")
            return 1
        if url and urllib.parse.urlsplit(url).username:
            print(
                f"verify_deploy: {label} for {env} carries credentials; remove them, the file is committed",
                file=sys.stderr,
            )
            summary(0, 0, "")
            return 1
    service = api or product

    # (check, url or "", expected status, version spec, contains, unfilled reason)
    plan = []
    for check, key in (("readiness", "readiness_path"), ("health", "health_path")):
        if s.get(key):
            plan.append(
                (
                    check,
                    join(service, s[key]),
                    "200",
                    "",
                    "",
                    "API base URL and product URL not filled",
                )
            )
    if s.get("version_path"):
        plan.append(
            (
                "version",
                join(service, s["version_path"]),
                "200",
                s.get("version_field", ""),
                "",
                "API base URL and product URL not filled",
            )
        )
    elif expect:
        # --expect cannot be compared without a version endpoint: a failed check
        plan.append(
            (
                "version",
                "",
                "200",
                "",
                "",
                "no Version path in the file to compare --expect with",
            )
        )
    for sm in smoke:
        base = api if sm["base"] == "api" else product
        why = ("API base URL" if sm["base"] == "api" else "Product URL") + " not filled"
        plan.append(
            (
                f"smoke: {sm['name']}",
                join(base, sm["path"]),
                sm["expect"] or "200",
                "",
                sm["contains"],
                why,
            )
        )
    if not plan:
        print(
            f"verify_deploy: '## {env}' in {a.file} defines 0 checks (no readiness, health, version or smoke path); nothing checked",
            file=sys.stderr,
        )
        summary(0, 0, "")
        return 1

    if not HAS_SSL and any(p[1].startswith("https://") for p in plan):
        print(
            f"verify_deploy: {sys.executable} has no ssl module, so it cannot check https; "
            "nothing was requested and no report written. Rerun with a python3 that has ssl "
            "(python3 -c 'import ssl' succeeds).",
            file=sys.stderr,
        )
        summary(0, 0, "")
        return 1

    results, deployed = [], ""
    for check, url, want, spec, contains, why in plan:
        expected = want
        if check == "version":
            expected = f"{want}, {spec or 'version field'} " + (
                f"= {expect}" if expect else "present"
            )
        if contains:
            expected += f', body has "{contains}"'
        if not url:
            results.append((check, "", expected, why, 0, False))
            continue
        status, headers, body, ms, err = fetch(url, a.timeout, a.retries)
        ok = not err and str(status) == want
        got = err or str(status)
        if check == "version" and not err:
            if not spec:
                ok, got = False, f"{status}, no Version field in the file"
            else:
                v = field_of(spec, headers, body)
                deployed = deployed or v
                got = f"{status}, {v or 'field missing'}"
                ok = ok and bool(v) and (matches(expect, v) if expect else True)
        if contains and not err:
            has = contains in body
            got += ", text found" if has else ", text missing"
            ok = ok and has
        results.append((check, url, expected, got, ms, ok))

    failed = sum(1 for r in results if not r[5])
    asked = [r for r in results if r[1]]
    unreached = [r for r in asked if str(r[3]).startswith("connection error")]
    unverified = bool(asked) and len(unreached) == len(asked)
    hosts = sorted({urllib.parse.urlsplit(r[1]).hostname or "" for r in unreached} - {""})
    reserved = [h for h in hosts if RESERVED.search(h)]
    reach = ""
    if unverified:
        reach = (
            f"unverified: none of the {len(asked)} checks got an answer from {', '.join(hosts)}. "
            "A connection error on every check says the hosts could not be reached from here, "
            "not that the deploy is broken. Check DNS, the VPN or network this ran from, the "
            "sandbox's allowed domains, and that the hostnames in the file are right, then rerun."
        )
    elif unreached:
        reach = f"{len(unreached)} of {len(asked)} checks got no answer (connection errors); the others did"
    if reserved:
        reach += (
            f" {', '.join(reserved)} "
            + ("is a reserved name" if len(reserved) == 1 else "are reserved names")
            + " that never resolve: the file holds a placeholder, not the real host."
        )
    for check, url, expected, got, ms, ok in results:
        print(
            f"{'pass' if ok else 'FAIL'} {check} {url or '-'}: expected {expected}; got {got} ({ms} ms)"
        )

    now = datetime.datetime.now(datetime.timezone.utc)
    os.makedirs(a.out, exist_ok=True)
    path = os.path.join(a.out, f"verify-{env}-{now.strftime('%Y-%m-%dT%H%M%SZ')}.md")
    rollback = s.get("rollback", "")
    lines = [
        f"# Deploy verification: {env}",
        "",
        f"When: {now.strftime('%Y-%m-%d %H:%M:%S')} UTC   File: {a.file}",
        f"Expected: {expect or 'not given'}   Deployed: {deployed or 'unknown'}   Owner: {s.get('owner') or 'not set'}",
        "",
        "| Check | URL | Expected | Got | ms | Result |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for check, url, expected, got, ms, ok in results:
        lines.append(
            f"| {cell(check)} | {cell(url or '-')} | {cell(expected)} | {cell(got)} | {ms} | {'pass' if ok else 'fail'} |"
        )
    lines.append("")
    if not failed:
        lines.append("Verdict: pass")
    elif unverified:
        lines.append(f"Verdict: unverified ({failed} of {len(results)} checks got no answer)")
    else:
        lines.append(f"Verdict: fail ({failed} of {len(results)} checks failed)")
    if reach:
        lines.append("")
        lines.append(reach.strip())
    if failed:
        lines.append("")
        lines.append(
            (
                "Rollback (the engineer decides, and only once a host answers and a check still fails): "
                if unverified
                else "Rollback (the engineer decides and acts): "
            )
            + (rollback or "not written in " + a.file)
        )
    lines.append("")
    lines.append(
        f"verify: {len(results)} checks, {failed} failed (env {env}, deployed {deployed or 'unknown'})"
    )
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"report: {path}")
    if reach:
        print(f"reach: {reach.strip()}")
    if failed:
        print(
            ("rollback (the engineer's call, not on this evidence): " if unverified else "rollback (the engineer's call): ")
            + (rollback or "not written in " + a.file)
        )
    summary(len(results), failed, deployed)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
