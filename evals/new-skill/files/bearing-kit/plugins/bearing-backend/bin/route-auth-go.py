#!/usr/bin/env python3
"""route-auth-go: every net/http mux route is wrapped in auth or listed as public.

Usage: route-auth-go.py <repo>
Reads every .go file outside vendor/ for mux.HandleFunc / mux.Handle calls.
A route is authenticated when its handler argument starts with requireAuth(.
Public routes are listed in <repo>/.bearing/public-routes.txt, one
"METHOD /path" per line. Prints each route without auth and the counts;
exits 1 when any route lacks auth.
"""

import os
import re
import sys

ROUTE = re.compile(r'\.Handle(?:Func)?\(\s*"([A-Z]+ [^"]+)"\s*,\s*([^\n]+)\)')


def public_routes(repo):
    path = os.path.join(repo, ".bearing", "public-routes.txt")
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8") as f:
        return {l.strip() for l in f if l.strip() and not l.startswith("#")}


def scan(repo):
    routes = []
    for d, dirs, files in os.walk(repo):
        dirs[:] = [x for x in dirs if x not in ("vendor", ".git")]
        for n in files:
            if not n.endswith(".go") or n.endswith("_test.go"):
                continue
            p = os.path.join(d, n)
            with open(p, encoding="utf-8") as f:
                for i, line in enumerate(f, 1):
                    m = ROUTE.search(line)
                    if m:
                        routes.append((os.path.relpath(p, repo), i, m.group(1), m.group(2)))
    return routes


def main(argv):
    if len(argv) != 2:
        print("usage: route-auth-go.py <repo>", file=sys.stderr)
        return 2
    repo = argv[1]
    public = public_routes(repo)
    routes = scan(repo)
    missing = [
        r for r in routes
        if not r[3].lstrip().startswith("requireAuth(") and r[2] not in public
    ]
    for path, line, pattern, _ in missing:
        print(f"{path}:{line}: {pattern} has no auth")
    print(f"route-auth-go: {len(routes)} routes, {len(missing)} without auth")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
