#!/usr/bin/env python3
"""Fake tracker for tests/contract/tracker_fake_server.sh.

One HTTP server answers the URL shapes of all four adapters: Jira Cloud
(/rest/api/3/...), GitLab (/api/v4/...), GitHub Enterprise (/api/v3/...) and the
REST tracker protocol of docs/TRACKERS.md (/api/...). Every request line and every header is appended
to --log so the test can prove which credentials arrived and how, byte for
byte. Nothing is contacted. --delay N sleeps N seconds before every answer
(the slow port that proves --max-time). The bound port is written to
--port-file once the socket is listening.

The fake keeps state in memory, per tracker: issues 1 and 2 (Jira PROJ-1 and
PROJ-2, REST tracker PP-17 and PP-18, ids 17 and 18) exist from the start, and a create or a
comment is stored, so a later list or search finds it. Lists paginate the
way each tracker does: GitLab and GitHub per_page/page with a Link
rel="next" header, Jira maxResults/nextPageToken/isLast, the REST
tracker limit/offset with X-Total-Count. Test controls (never used by an adapter,
never logged):

    POST /_fault?mode=after    the next POST is applied, then answered 502
    POST /_fault?mode=before   the next POST is answered 502, not applied
    POST /_seed?tracker=T&n=N  add N issues to tracker T (jira, gitlab, github, rest)
    GET  /_state?tracker=T     {"issues": n, "titles": [...], "comments": n}
    POST /_reset               back to the starting state
    POST /_nodocs              the REST tracker answers 404 on every document path

The REST tracker also keeps documents (the optional part of the protocol): a list
without content, a create answering the document, a get answering
{"document", "linked_issues"}, and a partial PUT answering {"ok": true}.

    fake_tracker.py --log <file> --port-file <file> [--delay <seconds>]
"""

import argparse
import json
import re
import socketserver
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlencode, urlsplit

ARGS = None
LOCK = threading.Lock()
STATE = {}


def key_num(key):
    """PROJ-7, GL-7, GH-7 and PP-7 all resolve to 7."""
    m = re.search(r"(\d+)$", key)
    return int(m.group(1)) if m else 1


def jira_issue(key, summary="Probe issue", props=None):
    return {
        "key": key,
        "id": str(10000 + key_num(key)),
        "fields": {
            "issuetype": {"name": "Story"},
            "summary": summary,
            "status": {"name": "To Do"},
            "assignee": None,
            "priority": {"name": "High"},
            "parent": None,
        },
        "_props": props or {},
    }


def gitlab_issue(iid, title="Probe issue", description="", labels=None):
    return {
        "iid": iid,
        "labels": labels or ["type::story", "status::todo"],
        "title": title,
        "description": description,
        "state": "opened",
        "assignee": None,
        "web_url": "http://fake/group/repo/-/issues/%d" % iid,
    }


def github_issue(number, title="Probe issue", body="", labels=None):
    return {
        "number": number,
        "labels": [{"name": n} for n in (labels or ["type:story", "status:todo"])],
        "title": title,
        "body": body,
        "state": "open",
        "assignee": None,
        "html_url": "http://fake/acme/probe/issues/%d" % number,
    }


def rest_issue(ident, title="Probe issue", typ="story", description=""):
    return {
        "id": ident,
        "key": "PP-%d" % ident,
        "type": typ,
        "project_id": 3,
        "title": title,
        "description": description,
        "status_name": "To Do",
        "assignee": None,
        "priority": "high",
    }


def reset():
    STATE.clear()
    STATE["fault"] = None
    STATE["jira"] = {
        "issues": [jira_issue("PROJ-1"), jira_issue("PROJ-2")],
        "next": 3,
        "comments": {},
        "next_comment": 5001,
    }
    STATE["gitlab"] = {
        "issues": [gitlab_issue(1), gitlab_issue(2)],
        "next": 3,
        "comments": {},
        "next_comment": 9,
    }
    STATE["github"] = {
        "issues": [github_issue(1), github_issue(2)],
        "next": 3,
        "comments": {},
        "next_comment": 11,
    }
    STATE["rest"] = {
        "issues": [rest_issue(17), rest_issue(18)],
        "next": 19,
        "comments": {},
        "next_comment": 7,
        "docs": [],
        "next_doc": 101,
        "nodocs": False,
    }


def seed(tracker, n):
    st = STATE[tracker]
    for _ in range(n):
        i = st["next"]
        st["next"] += 1
        title = "Seeded %d" % i
        if tracker == "jira":
            st["issues"].append(jira_issue("PROJ-%d" % i, title))
        elif tracker == "gitlab":
            st["issues"].append(gitlab_issue(i, title))
        elif tracker == "github":
            st["issues"].append(github_issue(i, title))
        else:
            st["issues"].append(rest_issue(i, title))


def title_of(tracker, item):
    if tracker == "jira":
        return item["fields"]["summary"]
    return item["title"]


def q1(query, name, default=None):
    return parse_qs(query).get(name, [default])[0]


def link_page(items, query, base, default_per, cap=100):
    """GitLab/GitHub style: per_page and page, Link rel="next" when more."""
    per = min(int(q1(query, "per_page", default_per)), cap)
    page = int(q1(query, "page", "1"))
    start = (page - 1) * per
    chunk = items[start : start + per]
    headers = {}
    if start + per < len(items):
        qs = {k: v[0] for k, v in parse_qs(query).items()}
        qs["page"] = str(page + 1)
        nxt = "%s?%s" % (base, urlencode(qs))
        headers["Link"] = '<%s>; rel="next", <%s>; rel="first"' % (nxt, base)
    return chunk, headers


def jira_view(issue, query):
    out = {k: v for k, v in issue.items() if k != "_props"}
    want = q1(query, "properties")
    if want:
        out["properties"] = {
            k: v for k, v in issue["_props"].items() if k in want.split(",")
        }
    return out


def route_jira(method, p, query, body):
    st = STATE["jira"]
    if p == "/myself":
        return (
            200,
            {
                "accountId": "5b10ac8d",
                "displayName": "Probe User",
                "emailAddress": "probe@example.com",
            },
            {},
        )
    if p == "/search/jql":
        items = list(st["issues"])
        if "DESC" in (q1(query, "jql", "") or ""):
            items.reverse()
        per = min(int(q1(query, "maxResults", "50")), 100)
        start = int(q1(query, "nextPageToken", "0"))
        chunk = [jira_view(i, query) for i in items[start : start + per]]
        out = {"issues": chunk, "isLast": start + per >= len(items)}
        if not out["isLast"]:
            out["nextPageToken"] = str(start + per)
        return 200, out, {}
    if p == "/issue" and method == "POST":
        f = (body or {}).get("fields", {})
        key = "PROJ-%d" % st["next"]
        st["next"] += 1
        props = {x["key"]: x["value"] for x in (body or {}).get("properties", [])}
        st["issues"].append(jira_issue(key, f.get("summary", ""), props))
        return 201, {"id": str(10000 + key_num(key)), "key": key}, {}
    if p == "/issueLink" and method == "POST":
        return 201, None, {}
    m2 = re.match(r"^/issue/([A-Z][A-Z0-9_]*-\d+)(/.*)?$", p)
    if m2:
        key, rest = m2.group(1), m2.group(2) or ""
        if rest == "" and method == "GET":
            found = [i for i in st["issues"] if i["key"] == key]
            return 200, jira_view(found[0] if found else jira_issue(key), ""), {}
        if rest == "" and method == "PUT":
            return 204, None, {}
        if rest == "/transitions" and method == "GET":
            return (
                200,
                {"transitions": [{"id": "31", "name": "Done", "to": {"name": "Done"}}]},
                {},
            )
        if rest == "/transitions" and method == "POST":
            return 204, None, {}
        if rest == "/comment" and method == "POST":
            cid = str(st["next_comment"])
            st["next_comment"] += 1
            st["comments"].setdefault(key, []).append(
                {
                    "id": cid,
                    "body": (body or {}).get("body"),
                    "properties": (body or {}).get("properties", []),
                }
            )
            return 201, {"id": cid}, {}
        if rest == "/comment" and method == "GET":
            items = list(st["comments"].get(key, []))
            if (q1(query, "orderBy", "") or "").startswith("-"):
                items.reverse()
            expand = "properties" in (q1(query, "expand", "") or "")
            view = [
                {k: v for k, v in c.items() if expand or k != "properties"}
                for c in items
            ]
            return 200, {"comments": view, "startAt": 0, "total": len(view)}, {}
        if rest == "/assignee" and method == "PUT":
            return 204, None, {}
    return 404, {"errorMessages": ["no such Jira shape: %s %s" % (method, p)]}, {}


def route_gitlab(method, p, query, body, base):
    st = STATE["gitlab"]
    if p == "/user":
        return 200, {"id": 1, "username": "probe", "name": "Probe User"}, {}
    m2 = re.match(r"^/projects/[^/]+/issues(?:/(\d+))?(/.*)?$", p)
    if m2:
        iid = int(m2.group(1)) if m2.group(1) else None
        rest = m2.group(2) or ""
        if iid is None and method == "GET":
            items = list(st["issues"])
            if q1(query, "sort") == "desc":
                items.reverse()
            return (200,) + link_page(items, query, base, 20)
        if iid is None and method == "POST":
            b = body or {}
            i = st["next"]
            st["next"] += 1
            labels = [x for x in (b.get("labels") or "").split(",") if x]
            issue = gitlab_issue(
                i, b.get("title", ""), b.get("description", ""), labels
            )
            st["issues"].append(issue)
            return 201, issue, {}
        found = [x for x in st["issues"] if x["iid"] == iid]
        issue = found[0] if found else gitlab_issue(iid)
        if rest == "" and method in ("GET", "PUT"):
            return 200, issue, {}
        if rest == "/notes" and method == "POST":
            nid = st["next_comment"]
            st["next_comment"] += 1
            st["comments"].setdefault(iid, []).append(
                {"id": nid, "body": (body or {}).get("body", "")}
            )
            return 201, {"id": nid}, {}
        if rest == "/notes" and method == "GET":
            items = list(st["comments"].get(iid, []))
            if q1(query, "sort") == "desc":
                items.reverse()
            return (200,) + link_page(items, query, base, 20)
        if rest == "/links" and method == "POST":
            return 201, {"source_issue": issue}, {}
    return 404, {"message": "no such GitLab shape: %s %s" % (method, p)}, {}


def route_github(method, p, query, body, base):
    st = STATE["github"]
    if p == "/user":
        return 200, {"login": "probe", "name": "Probe User"}, {}
    if p == "/search/issues":
        chunk, headers = link_page(st["issues"], query, base, 30)
        return 200, {"total_count": len(st["issues"]), "items": chunk}, headers
    m2 = re.match(r"^/repos/[^/]+/[^/]+/labels(?:/([^/]+))?$", p)
    if m2:
        if method == "GET":
            return 200, {"name": m2.group(1) or ""}, {}
        return 201, {"name": "created"}, {}
    m2 = re.match(r"^/repos/[^/]+/[^/]+/issues(?:/(\d+))?(/.*)?$", p)
    if m2:
        number = int(m2.group(1)) if m2.group(1) else None
        rest = m2.group(2) or ""
        if number is None and method == "GET":
            items = list(st["issues"])
            if q1(query, "direction") == "desc":
                items.reverse()
            return (200,) + link_page(items, query, base, 30)
        if number is None and method == "POST":
            b = body or {}
            n = st["next"]
            st["next"] += 1
            issue = github_issue(
                n, b.get("title", ""), b.get("body", ""), b.get("labels")
            )
            st["issues"].append(issue)
            return 201, issue, {}
        found = [x for x in st["issues"] if x["number"] == number]
        issue = found[0] if found else github_issue(number)
        if rest == "" and method in ("GET", "PATCH"):
            return 200, issue, {}
        if rest == "/comments" and method == "POST":
            cid = st["next_comment"]
            st["next_comment"] += 1
            st["comments"].setdefault(number, []).append(
                {"id": cid, "body": (body or {}).get("body", "")}
            )
            return 201, {"id": cid}, {}
        if rest == "/comments" and method == "GET":
            return (200,) + link_page(st["comments"].get(number, []), query, base, 30)
    return 404, {"message": "no such GitHub shape: %s %s" % (method, p)}, {}


DOC_TYPES = {"prd", "design", "doc"}


def route_rest_docs(method, p, body):
    """The protocol's optional document shapes, or None when p is not a document path."""
    st = STATE["rest"]
    m = re.match(r"^/projects/([^/]+)/documents$", p)
    d = re.match(r"^/documents/(\d+)$", p)
    if not (m or d):
        return None
    if st["nodocs"]:
        return 404, {"error": "not found"}, {}
    b = body or {}
    if m and method == "GET":
        return 200, [{k: v for k, v in x.items() if k != "content"} for x in st["docs"]], {}
    if m and method == "POST":
        if not b.get("title"):
            return 400, {"error": "title is required"}, {}
        parent = b.get("parent_id")
        if parent is not None and not any(x["id"] == parent for x in st["docs"]):
            return 400, {"error": "parent_id must reference a document in this project"}, {}
        doc = {
            "id": st["next_doc"],
            "project_id": 3,
            "parent_id": parent,
            "doc_type": b.get("doc_type") if b.get("doc_type") in DOC_TYPES else "doc",
            "title": b["title"],
            "content": b.get("content", ""),
        }
        st["next_doc"] += 1
        st["docs"].append(doc)
        return 201, doc, {}
    found = [x for x in st["docs"] if x["id"] == int(d.group(1))] if d else []
    if not found:
        return 404, {"error": "document not found"}, {}
    doc = found[0]
    if method == "GET":
        linked = [i["key"] for i in st["issues"] if i.get("document_id") == doc["id"]]
        return 200, {"document": doc, "linked_issues": linked}, {}
    if method == "PUT":
        for k in ("title", "content", "parent_id"):
            if k in b:
                doc[k] = b[k]
        if b.get("doc_type") in DOC_TYPES:
            doc["doc_type"] = b["doc_type"]
        return 200, {"ok": True}, {}
    return 405, {"error": "method not allowed"}, {}


def route_rest(method, p, query, body):
    st = STATE["rest"]
    docs = route_rest_docs(method, p, body)
    if docs is not None:
        return docs
    if p == "/auth/me":
        return 200, {"id": 1, "name": "Probe User", "email": "probe@example.com"}, {}
    if p == "/auth/login" and method == "POST":
        return 200, {"token": "login-should-not-be-needed"}, {}
    if p == "/search":
        q = q1(query, "q", "")
        return 200, {"issues": [{"key": q, "id": key_num(q)}]}, {}
    if p == "/projects" and method == "GET":
        return 200, [{"id": 3, "key": "PP", "name": "Probe Project"}], {}
    m2 = re.match(r"^/projects/([^/]+)/(statuses|members|labels|issues)$", p)
    if m2:
        what = m2.group(2)
        if what == "statuses":
            return (
                200,
                [
                    {"id": 5, "type": "story", "name": "Done", "category": "done"},
                    {"id": 4, "type": "story", "name": "To Do", "category": "todo"},
                ],
                {},
            )
        if what == "members":
            return 200, [{"id": 1, "email": "probe@example.com"}], {}
        if what == "labels":
            return 200, [], {}
        if method == "GET":
            # The real list leaves the description out; so does the fake.
            typ = q1(query, "type")
            items = [
                {k: v for k, v in i.items() if k != "description"}
                for i in st["issues"]
                if not typ or i["type"] == typ
            ]
            limit = min(int(q1(query, "limit", "200")), 1000)
            offset = int(q1(query, "offset", "0"))
            return (
                200,
                items[offset : offset + limit],
                {"X-Total-Count": str(len(items))},
            )
        b = body or {}
        i = st["next"]
        st["next"] += 1
        issue = rest_issue(
            i, b.get("title", ""), b.get("type", "task"), b.get("description", "")
        )
        if "document_id" in b:
            issue["document_id"] = b["document_id"]
        st["issues"].append(issue)
        return 201, issue, {}
    m2 = re.match(r"^/issues/(\d+)(/.*)?$", p)
    if m2:
        ident, rest = int(m2.group(1)), m2.group(2) or ""
        found = [x for x in st["issues"] if x["id"] == ident]
        issue = found[0] if found else rest_issue(ident)
        if rest == "" and method == "GET":
            return 200, {"issue": issue, "comments": st["comments"].get(ident, [])}, {}
        if rest == "" and method == "PUT":
            if found and "document_id" in (body or {}):
                issue["document_id"] = body["document_id"]
            return 200, issue, {}
        if rest == "/comments" and method == "POST":
            c = {
                "id": st["next_comment"],
                "issue_id": ident,
                "body": (body or {}).get("body", ""),
                "created_at": "2026-09-22T00:00:00Z",
            }
            st["next_comment"] += 1
            st["comments"].setdefault(ident, []).append(c)
            return 201, c, {}
        if rest == "/links" and method == "POST":
            return 201, {"id": 8}, {}
    return 404, {"error": "no such REST tracker shape: %s %s" % (method, p)}, {}


def route(method, path, query, body, base):
    """(status, object or None, headers). Unknown shapes answer 404."""
    m = re.match(r"^/rest/api/3(/.*)$", path)
    if m:
        return route_jira(method, m.group(1), query, body)
    m = re.match(r"^/api/v4(/.*)$", path)
    if m:
        return route_gitlab(method, m.group(1), query, body, base + path)
    m = re.match(r"^/api/v3(/.*)$", path)
    if m:
        return route_github(method, m.group(1), query, body, base + path)
    m = re.match(r"^/api(/.*)$", path)
    if m:
        return route_rest(method, m.group(1), query, body)
    if path == "/healthz":
        return 200, {"ok": True}, {}
    return 404, {"error": "unknown path %s" % path}, {}


def control(method, path, query):
    """Test-only endpoints under /_. None when the path is not one."""
    if path == "/_reset" and method == "POST":
        reset()
        return 200, {"ok": True}
    if path == "/_fault" and method == "POST":
        STATE["fault"] = q1(query, "mode", "after")
        return 200, {"fault": STATE["fault"]}
    if path == "/_seed" and method == "POST":
        seed(q1(query, "tracker"), int(q1(query, "n", "0")))
        return 200, {"ok": True}
    if path == "/_nodocs" and method == "POST":
        STATE["rest"]["nodocs"] = True
        return 200, {"ok": True}
    if path == "/_state" and method == "GET":
        t = q1(query, "tracker")
        st = STATE[t]
        return 200, {
            "issues": len(st["issues"]),
            "titles": [title_of(t, i) for i in st["issues"]],
            "comments": sum(len(v) for v in st["comments"].values()),
            "documents": len(st.get("docs", [])),
            "doc_titles": [x["title"] for x in st.get("docs", [])],
            "document_ids": {i["key"]: i["document_id"] for i in st["issues"] if "document_id" in i}
            if t == "rest"
            else {},
        }
    return None


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # keep the test output quiet
        pass

    def _serve(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        try:
            body = json.loads(raw.decode("utf-8")) if raw else None
        except ValueError:
            body = None
        parts = urlsplit(self.path)
        headers = {}
        with LOCK:
            ctl = control(self.command, parts.path, parts.query)
            if ctl is None:
                with open(ARGS.log, "a", encoding="utf-8") as fh:
                    fh.write("%s %s\n" % (self.command, self.path))
                    for name, value in self.headers.items():
                        fh.write("H: %s: %s\n" % (name, value))
                    fh.write("\n")
        if ctl is not None:
            status, obj = ctl
        else:
            if ARGS.delay:
                time.sleep(ARGS.delay)
            base = "http://%s" % self.headers.get("Host", "127.0.0.1")
            with LOCK:
                fault = STATE["fault"] if self.command == "POST" else None
                if fault:
                    STATE["fault"] = None
                if fault == "before":
                    status, obj = 502, {"message": "bad gateway (fault before)"}
                else:
                    status, obj, headers = route(
                        self.command, parts.path, parts.query, body, base
                    )
                    if fault == "after":
                        status, obj, headers = (
                            502,
                            {"message": "bad gateway (fault after)"},
                            {},
                        )
        payload = b"" if obj is None else json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        for name, value in headers.items():
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if payload:
            self.wfile.write(payload)

    do_GET = _serve
    do_POST = _serve
    do_PUT = _serve
    do_PATCH = _serve
    do_DELETE = _serve


def main():
    global ARGS
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--log", required=True)
    ap.add_argument("--port-file", required=True)
    ap.add_argument("--delay", type=float, default=0)
    ARGS = ap.parse_args()
    reset()
    server = QuickServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    with open(ARGS.port_file, "w", encoding="utf-8") as fh:
        fh.write("%d\n" % server.server_address[1])
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


class QuickServer(ThreadingHTTPServer):
    """HTTPServer.server_bind resolves its name with socket.getfqdn, a reverse
    lookup that can stall for many seconds on a macOS runner before the port
    file is written. The name is never used here, so skip the lookup."""

    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]


if __name__ == "__main__":
    sys.exit(main())
