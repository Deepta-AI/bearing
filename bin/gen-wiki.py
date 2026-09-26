#!/usr/bin/env python3
"""gen-wiki: export the kit's docs as GitLab (or GitHub) wiki pages.

For hosts where the handbook site cannot be published (no Vercel project
and no GitLab Pages), the same content goes to the project wiki as plain
markdown. The page names follow GitLab's wiki; a GitHub wiki wants Home
and _Sidebar for the two special pages:

  home.md                 README.md
  Workflow.md             docs/WORKFLOW.md (the stage map)
  Flow-<title>.md         each flow in docs/flows.json, as a step list
  Skills.md, Install.md, Trackers.md, Third-party-packs.md,
  Repository-layout.md    the matching docs/ files
  _sidebar.md             the navigation

A link between exported docs becomes a wiki link. A link to any other file
in the repository becomes a link to that file on the default branch when
--repo-url is given, else plain text (a relative link would 404 in a wiki).
Every page opens with the source it was generated from and the last commit
that changed that source, so a reader can tell a stale page from a current
one, and an export after commits that left a doc alone leaves its page
byte for byte the same (no wiki commit that changes only a stamp).

Usage: gen-wiki.py <out-dir> [--repo-url https://host/group/project] [--branch main] [--any-dir]

The out-dir must be a clone of the wiki repository (--any-dir allows any
folder, for a preview); pages
this script owns are overwritten, other pages are left alone. Prints the
counts and exits 1 when zero pages were written or a source is missing.
"""

import argparse
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# source path (from the kit root) -> wiki page slug
DOCS = {
    "README.md": "home",
    "docs/WORKFLOW.md": "Workflow",
    "docs/SKILLS.md": "Skills",
    "docs/INSTALL.md": "Install",
    "docs/TRACKERS.md": "Trackers",
    "docs/THIRD_PARTY.md": "Third-party-packs",
    "docs/REPO_LAYOUT.md": "Repository-layout",
}
FLOWS = "docs/flows.json"
LINK = re.compile(r"(!?)\[([^\]]*)\]\(([^)\s]+)\)")


def run(*cmd):
    try:
        return subprocess.run(
            cmd, cwd=ROOT, capture_output=True, text=True, check=True
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def default_repo_url():
    """git@host:group/project.git or https://host/group/project.git -> https://host/group/project."""
    url = run("git", "remote", "get-url", "origin")
    m = re.match(r"^git@([^:]+):(.+?)(\.git)?$", url) or re.match(
        r"^ssh://git@([^/:]+)(?::\d+)?/(.+?)(\.git)?$", url
    )
    if m:
        return f"https://{m.group(1)}/{m.group(2)}"
    m = re.match(r"^(https?://.+?)(\.git)?$", url)
    return m.group(1) if m else ""


def blob(repo_url, kind, branch, rel):
    """A file or folder URL on the host: GitHub has no "/-" segment, GitLab does."""
    sep = "" if "github.com" in repo_url else "/-"
    return f"{repo_url}{sep}/{kind}/{branch}/{rel}"


def slug(title):
    return "Flow-" + re.sub(r"[^A-Za-z0-9]+", "-", title).strip("-")


class Linker:
    """Rewrites the links in one source file; counts what it did."""

    def __init__(self, repo_url, branch):
        self.repo_url = repo_url.rstrip("/")
        self.branch = branch
        self.wiki = self.repo = self.plain = 0

    def rewrite(self, text, src):
        base = os.path.dirname(src)

        def one(m):
            bang, label, target = m.groups()
            if re.match(r"^[a-z][a-z0-9+.-]*:", target) or target.startswith("#"):
                return m.group(0)
            path, _, anchor = target.partition("#")
            rel = os.path.normpath(os.path.join(base, path)).replace(os.sep, "/")
            frag = f"#{anchor}" if anchor else ""
            if rel in DOCS:
                self.wiki += 1
                return f"{bang}[{label}]({DOCS[rel]}{frag})"
            if not os.path.exists(os.path.join(ROOT, rel)):
                self.plain += 1
                return label
            if self.repo_url:
                self.repo += 1
                kind = "tree" if os.path.isdir(os.path.join(ROOT, rel)) else "blob"
                return f"{bang}[{label}]({blob(self.repo_url, kind, self.branch, rel)}{frag})"
            self.plain += 1
            return f"{label} (`{rel}`)"

        return LINK.sub(one, text)


def source_commit(src):
    """The last commit that changed src; "uncommitted" when the working tree differs from it."""
    if run("git", "status", "--porcelain", "--", src):
        return "uncommitted"
    return run("git", "log", "-1", "--format=%h", "--", src) or "unknown"


def banner(src, commit, repo_url, branch):
    where = f"[{src}]({blob(repo_url, 'blob', branch, src)})" if repo_url else f"`{src}`"
    return (
        f"> Generated from {where} at commit `{commit}` by `make wiki`. "
        "Edit the source in the repository, not this page: the next export overwrites it.\n\n"
    )


def esc(text):
    """flows.json text is prose with <ID>-style slots; a wiki drops them as HTML tags."""
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def render_steps(steps, flow_titles, depth=0):
    out = []
    pad = "  " * depth
    for s in steps:
        kind = s["kind"]
        if kind == "phase":
            out.append(
                f"\n{'#' * min(2 + depth, 4)} {s['title']}\n"
                if depth == 0
                else f"{pad}- *{s['title']}*"
            )
        elif kind == "step":
            out.append(
                f"{pad}- **{s['title']}**: `{s['skill']}` ({s['pack']}). {esc(s['does'])}"
            )
            out.append(f"{pad}  - Output: {esc(s['output'])}")
            out.append(f"{pad}  - Why: {esc(s['why'])}")
        elif kind == "branch":
            out.append(f"{pad}- **{esc(s['question'])}**")
            for o in s["options"]:
                if o["steps"]:
                    out.append(f"{pad}  - {esc(o['label'])}:")
                    out.extend(render_steps(o["steps"], flow_titles, depth + 2))
                else:
                    out.append(f"{pad}  - {esc(o['label'])}: carry on.")
        elif kind == "link":
            target = flow_titles.get(s["flow"])
            if not target:
                sys.exit(f"gen-wiki: {FLOWS} links to an unknown flow '{s['flow']}'")
            out.append(f"{pad}- **{s['title']}**: see [{target}]({slug(target)}).")
        else:
            sys.exit(f"gen-wiki: {FLOWS} has a step of unknown kind '{kind}'")
    return out


def main():
    ap = argparse.ArgumentParser(description="Export the kit's docs as wiki pages.")
    ap.add_argument("out")
    ap.add_argument(
        "--repo-url",
        default=None,
        help="web URL of the repository (default: from the origin remote)",
    )
    ap.add_argument("--branch", default="main")
    ap.add_argument(
        "--any-dir",
        action="store_true",
        help="write into a folder that is not a clone of the wiki (a preview; nothing to push)",
    )
    args = ap.parse_args()

    repo_url = default_repo_url() if args.repo_url is None else args.repo_url
    commit = run("git", "rev-parse", "--short", "HEAD") or "unknown"
    missing = [p for p in [*DOCS, FLOWS] if not os.path.isfile(os.path.join(ROOT, p))]
    if missing:
        sys.exit(f"gen-wiki: sources missing: {', '.join(missing)}; 0 pages written")
    flows = json.load(open(os.path.join(ROOT, FLOWS), encoding="utf-8"))["flows"]
    if not flows:
        sys.exit(f"gen-wiki: 0 flows in {FLOWS}; 0 pages written")
    flow_titles = {f["id"]: f["title"] for f in flows}

    # A folder that is not a clone of the wiki cannot be pushed, so an export
    # into it looks like success and publishes nothing.
    if not args.any_dir and not os.path.exists(os.path.join(args.out, ".git")):
        sys.exit(
            f"gen-wiki: {args.out} is not a clone of the wiki repository (no .git); "
            "clone <repository>.wiki.git there first, or pass --any-dir for a preview. 0 pages written"
        )
    os.makedirs(args.out, exist_ok=True)
    linker = Linker(repo_url, args.branch)
    pages = []

    def write(name, body):
        with open(os.path.join(args.out, f"{name}.md"), "w", encoding="utf-8") as fh:
            fh.write(body.rstrip() + "\n")
        pages.append(name)

    for src, name in DOCS.items():
        text = open(os.path.join(ROOT, src), encoding="utf-8").read()
        write(
            name,
            banner(src, source_commit(src), repo_url, args.branch)
            + linker.rewrite(text, src),
        )

    for f in flows:
        lines = [f"# {f['title']}", "", f"{f['tagline']}", "", f"**When:** {esc(f['when'])}", ""]
        lines += render_steps(f["steps"], flow_titles)
        write(
            slug(f["title"]),
            banner(FLOWS, source_commit(FLOWS), repo_url, args.branch)
            + "\n".join(lines),
        )

    nav = [
        "- [Home](home)",
        "- [Install](Install)",
        "- [Workflow](Workflow)",
        "- Flows",
    ]
    nav += [f"  - [{f['title']}]({slug(f['title'])})" for f in flows]
    nav += [
        "- [Skills](Skills)",
        "- [Trackers](Trackers)",
        "- [Third-party packs](Third-party-packs)",
        "- [Repository layout](Repository-layout)",
    ]
    write("_sidebar", "\n".join(nav))

    content = [p for p in pages if p != "_sidebar"]
    if not content:
        sys.exit("gen-wiki: 0 pages written")
    print(
        f"gen-wiki: {len(content)} pages and a sidebar written to {args.out} "
        f"({len(DOCS)} docs, {len(flows)} flows); links: {linker.wiki} to wiki pages, "
        f"{linker.repo} to the repository, {linker.plain} made plain text; commit {commit}; "
        f"repository links point at {repo_url or 'nothing (no --repo-url, no origin remote)'}"
    )


if __name__ == "__main__":
    main()
