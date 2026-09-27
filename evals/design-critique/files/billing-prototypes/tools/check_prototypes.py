#!/usr/bin/env python3
"""check_prototypes: every HTML prototype under a folder has a language, a
title and a viewport, every local stylesheet it links exists, and every
var(--name) its own styles use without a fallback is defined in a
stylesheet it links or in the page itself.

Usage: check_prototypes.py <folder>
Prints one line per problem and the count of pages checked; exits 1 on any
problem, or when no page was found.
"""

import os
import re
import sys
from html.parser import HTMLParser


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.lang = False
        self.title = False
        self.viewport = False
        self.sheets = []
        self.css = []
        self.in_style = False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "html" and a.get("lang"):
            self.lang = True
        elif tag == "title":
            self.title = True
        elif tag == "meta" and a.get("name") == "viewport":
            self.viewport = True
        elif tag == "link" and a.get("rel") == "stylesheet":
            self.sheets.append(a.get("href", ""))
        elif tag == "style":
            self.in_style = True
        if a.get("style"):
            self.css.append(a["style"])

    def handle_endtag(self, tag):
        if tag == "style":
            self.in_style = False

    def handle_data(self, data):
        if self.in_style:
            self.css.append(data)


DEFINED = re.compile(r"(--[\w-]+)\s*:")
USED = re.compile(r"var\(\s*(--[\w-]+)\s*\)")


def main():
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        print("prototype-check: give a folder", file=sys.stderr)
        return 1
    problems, pages = [], 0
    for d, _, names in sorted(os.walk(sys.argv[1])):
        for n in sorted(names):
            if not n.endswith(".html"):
                continue
            path = os.path.join(d, n)
            pages += 1
            p = Page()
            p.feed(open(path, encoding="utf-8").read())
            own = "\n".join(p.css)
            defined = set(DEFINED.findall(own))
            if not p.lang:
                problems.append(f"{path}: no lang on <html>")
            if not p.title:
                problems.append(f"{path}: no <title>")
            if not p.viewport:
                problems.append(f"{path}: no viewport meta")
            for href in p.sheets:
                if href.startswith(("http://", "https://")):
                    continue
                sheet = os.path.join(d, href)
                if not os.path.isfile(sheet):
                    problems.append(f"{path}: stylesheet {href} not found")
                    continue
                defined |= set(DEFINED.findall(open(sheet, encoding="utf-8").read()))
            for name in sorted(set(USED.findall(own)) - defined):
                problems.append(f"{path}: var({name}) is not defined")
    for pr in problems:
        print(f"problem: {pr}")
    print(f"prototype-check: {pages} pages, {len(problems)} problems")
    if pages == 0:
        print("prototype-check: 0 pages found, nothing checked", file=sys.stderr)
        return 1
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
