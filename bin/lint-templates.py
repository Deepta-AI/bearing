#!/usr/bin/env python3
"""lint-templates: every document template tells its author what good looks like.

A document template (a markdown file under plugins/*/skills/*/templates*/
or plugins/bearing/templates/repo/docs/templates/) must open with a
guidance comment, and every ## or ### section in it must carry a comment of its own with a "What:" line
(what goes there) and a "Good:" line (what a strong entry has). Skills delete
the comments when they fill the section, so a finished document stays clean.

Templates that are code, not documents (an MCP server, a gateway module, a
stack README a scaffold writes) are listed in bin/lint-templates.skip as
"path|reason"; a listed path that no longer exists is a problem, so the list
cannot go stale.

Usage: lint-templates.py [kit root]
Prints one line per problem and the counts; exits 1 on any problem or when
zero templates were checked.
"""

import glob
import os
import re
import sys

root = (
    sys.argv[1]
    if len(sys.argv) > 1
    else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)
os.chdir(root)

skip = {}
for line in open("bin/lint-templates.skip", encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    path, _, reason = line.partition("|")
    skip[path.strip()] = reason.strip()

paths = sorted(
    p
    for p in glob.glob("plugins/*/skills/*/templates*/**/*.md", recursive=True)
    + glob.glob("plugins/bearing/templates/repo/docs/templates/*.md")
    if "/skeleton/" not in p and "/evals/" not in p
)
problems = []
for s in skip:
    if s not in paths:
        problems.append(f"bin/lint-templates.skip: {s} is not a template any more")
    elif not skip[s]:
        problems.append(f"bin/lint-templates.skip: {s} has no reason")

checked = sections = 0
for p in paths:
    if p in skip:
        continue
    checked += 1
    text = open(p, encoding="utf-8").read()
    # Drop fenced code so a heading inside an example block is not a section.
    body = re.sub(r"^```.*?^```", "", text, flags=re.M | re.S)
    first = body.lstrip()
    head_end = re.search(r"^##", body, re.M)
    preamble = body[: head_end.start()] if head_end else body
    if "<!--" not in preamble:
        problems.append(f"{p}: no guidance comment before the first section")
    parts = re.split(r"^(#{2,3} .*)$", body, flags=re.M)
    for i in range(1, len(parts), 2):
        heading, content = parts[i].strip(), parts[i + 1]
        sections += 1
        comments = re.findall(r"<!--(.*?)-->", content, re.S)
        if not comments:
            problems.append(f"{p}: '{heading}' has no guidance comment")
            continue
        joined = " ".join(comments)
        for key in ("What:", "Good:"):
            if key not in joined:
                problems.append(f"{p}: '{heading}' guidance has no {key} line")
    if not first:
        problems.append(f"{p}: empty")

# plugins/bearing/templates/repo/docs/templates/ holds copies a new repository gets; the skill
# owning each template is the source, so a copy must match it byte for byte.
for p in glob.glob("plugins/bearing/templates/repo/docs/templates/*.md"):
    owners = glob.glob("plugins/*/skills/*/templates/" + os.path.basename(p))
    if len(owners) != 1:
        problems.append(f"{p}: {len(owners)} skill templates named {os.path.basename(p)}; want exactly one source")
    elif open(p, encoding="utf-8").read() != open(owners[0], encoding="utf-8").read():
        problems.append(f"{p}: differs from its source {owners[0]} (copy it)")

# The change-request templates a repository gets are copies of merge-request's.
for p in ("plugins/bearing/templates/repo/.gitlab/merge_request_templates/Default.md", "plugins/bearing/templates/repo/.github/PULL_REQUEST_TEMPLATE.md"):
    src = "plugins/bearing/skills/merge-request/templates/mr.md"
    if not os.path.isfile(p) or open(p, encoding="utf-8").read() != open(src, encoding="utf-8").read():
        problems.append(f"{p}: differs from its source {src} (copy it)")

for q in problems:
    print(f"problem: {q}")
if checked == 0:
    print("lint-templates: 0 templates, nothing checked", file=sys.stderr)
    sys.exit(1)
print(
    f"lint-templates: {checked} document templates, {sections} sections, {len(skip)} code templates skipped, {len(problems)} problems"
)
sys.exit(1 if problems else 0)
