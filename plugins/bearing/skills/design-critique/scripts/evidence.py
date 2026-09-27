#!/usr/bin/env python3
"""evidence: take and check the design review's screenshots, so the widths
and themes in the report are counted from files, not claimed.

  evidence.py shoot --base <url or folder> --out <shots dir> [--browse BIN] [--chrome BIN] <page>...
      For each page: goto, then a viewport screenshot at 375x812, 768x1024
      and 1440x900 in light, then dark (documentElement.dataset.theme =
      'dark') at the same three widths. Records the computed background and
      text colours of the first 60 elements in each theme to
      <page>.theme.json, and console errors to <page>.console.txt.
      A <page> is a file name in the folder (a.html) or a path under the URL.
      When browse is absent or its browser cannot start, it falls back to a
      local headless Chrome or Chromium: the same six shots, dark through
      prefers-color-scheme (--force-dark-mode) instead of data-theme, the
      theme record holds the shot digests and console errors are not
      recorded. The last line names the engine and the dark path used.

  evidence.py check --out <shots dir> <page>...
      Every page needs six PNGs: <page>-<w>.png and <page>-<w>-dark.png for
      w in 375, 768, 1440. Each must be a PNG whose width is the viewport
      width (or a whole multiple of it, for a device pixel ratio above 1).
      A dark shot byte-identical to its light shot, or a theme record whose
      dark colours equal its light colours, means the dark theme never
      applied: a colour finding, and a failed check. The counts line names
      the dark path the shots used; the other path was not rendered.

Browse runs with its state and logs in a temporary folder, stopped and
removed after the shoot; a tool folder that still appears at the repository
root (.gstack, .playwright-mcp) is removed and named.

Both print "design-evidence: ..." with counts and exit 1 on any problem, or
when zero pages were given.
"""

import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import urllib.parse

WIDTHS = [(375, 812), (768, 1024), (1440, 900)]
DEFAULT_BROWSE = os.path.expanduser("~/.claude/skills/gstack/browse/dist/browse")
SIGNATURE_JS = (
    "JSON.stringify([document.documentElement,document.body,"
    "...document.body.querySelectorAll('*')].slice(0,60).map(e=>{"
    "const s=getComputedStyle(e);return s.backgroundColor+'|'+s.color}))"
)


def stem(page):
    # a fragment (#chrome=0) or query steers the page, not the file name
    page = page.split("#", 1)[0].split("?", 1)[0]
    base = page.rstrip("/").split("/")[-1] or "index"
    return base[:-5] if base.endswith(".html") else base


def page_url(base, page):
    if os.path.isdir(base):
        return "file://" + os.path.abspath(os.path.join(base, page))
    return urllib.parse.urljoin(base.rstrip("/") + "/", page.lstrip("/"))


# browse keeps its daemon state and logs in <git root>/.gstack/ unless told
# otherwise; that would leave files in the repository under review. It gets a
# state file in a temporary folder instead, removed after the shoot.
BROWSE_ENV = dict(os.environ)


def browse(bin_, *args):
    r = subprocess.run(
        [bin_, *args], capture_output=True, text=True, timeout=120, env=BROWSE_ENV
    )
    if r.returncode != 0:
        raise RuntimeError(
            f"browse {' '.join(args[:2])}: {(r.stderr or r.stdout).strip()[:200]}"
        )
    return r.stdout


def last_line(out):
    lines = [l for l in out.strip().split("\n") if l and not l.startswith("[browse]")]
    return lines[-1] if lines else ""


CHROMES = ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"]


def find_chrome(explicit):
    if explicit:
        return explicit if shutil.which(explicit) or os.path.isfile(explicit) else None
    for c in CHROMES:
        if shutil.which(c):
            return shutil.which(c)
    return None


def chrome_shot(bin_, url, path, w, h, dark, profile):
    args = [bin_, "--headless=new", "--disable-gpu", "--no-first-run",
            "--hide-scrollbars", f"--user-data-dir={profile}",
            f"--window-size={w},{h}", f"--screenshot={path}", url]
    if dark:
        args.insert(1, "--force-dark-mode")
    subprocess.run(args, capture_output=True, text=True, timeout=120)
    if not os.path.isfile(path):
        raise RuntimeError(f"chrome wrote no {os.path.basename(path)}")


def shoot_chrome(a, bin_):
    os.makedirs(a.out, exist_ok=True)
    profile = tempfile.mkdtemp(prefix="evidence-chrome-")
    shots = 0
    try:
        for page in a.pages:
            name = stem(page)
            url = page_url(a.base, page)
            record = {"url": url, "engine": "chrome", "dark_path": "prefers-color-scheme"}
            for theme in ("light", "dark"):
                suffix = "-dark" if theme == "dark" else ""
                for w, h in WIDTHS:
                    p = os.path.join(a.out, f"{name}-{w}{suffix}.png")
                    chrome_shot(bin_, url, p, w, h, theme == "dark", profile)
                    shots += 1
                record[theme] = digest(os.path.join(a.out, f"{name}-1440{suffix}.png"))
            with open(os.path.join(a.out, f"{name}.theme.json"), "w", encoding="utf-8") as f:
                json.dump(record, f, indent=1)
            with open(os.path.join(a.out, f"{name}.console.txt"), "w", encoding="utf-8") as f:
                f.write("not recorded (chrome fallback)\n")
    finally:
        shutil.rmtree(profile, ignore_errors=True)
    print(
        f"design-evidence: shot {len(a.pages)} pages, {shots} screenshots into {a.out} "
        f"(engine chrome, dark via prefers-color-scheme; a page themed only by data-theme shows no dark here)"
    )
    return 0 if shots else 1


def shoot(a):
    if os.path.isdir(a.base):
        missing = [p for p in a.pages if not os.path.isfile(os.path.join(a.base, p.split("#")[0].split("?")[0]))]
        if missing:
            print(f"design-evidence: no such page in {a.base}: {', '.join(missing)}", file=sys.stderr)
            return 1
    usable = os.path.isfile(a.browse) and os.access(a.browse, os.X_OK)
    if usable:
        state = tempfile.mkdtemp(prefix="evidence-browse-")
        BROWSE_ENV["BROWSE_STATE_FILE"] = os.path.join(state, ".gstack", "browse.json")
        try:
            return shoot_browse(a)
        except RuntimeError as e:
            print(f"design-evidence: browse failed ({e}); trying chrome", file=sys.stderr)
        finally:
            try:
                subprocess.run([a.browse, "stop"], capture_output=True, timeout=30, env=BROWSE_ENV)
            except (OSError, subprocess.TimeoutExpired):
                pass
            shutil.rmtree(state, ignore_errors=True)
    chrome = find_chrome(a.chrome)
    if chrome:
        return shoot_chrome(a, chrome)
    print(
        f"design-evidence: browse not usable at {a.browse} and no chrome or chromium found; "
        "no screenshots taken",
        file=sys.stderr,
    )
    return 1


def shoot_browse(a):
    os.makedirs(a.out, exist_ok=True)
    shots = 0
    for page in a.pages:
        name = stem(page)
        url = page_url(a.base, page)
        browse(a.browse, "goto", url)
        record = {"url": url, "engine": "browse", "dark_path": "data-theme"}
        for theme in ("light", "dark"):
            if theme == "dark":
                browse(a.browse, "js", "document.documentElement.dataset.theme='dark'")
            for w, h in WIDTHS:
                browse(a.browse, "viewport", f"{w}x{h}")
                suffix = "-dark" if theme == "dark" else ""
                browse(
                    a.browse,
                    "screenshot",
                    "--viewport",
                    os.path.join(a.out, f"{name}-{w}{suffix}.png"),
                )
                shots += 1
            record[theme] = last_line(browse(a.browse, "js", SIGNATURE_JS))
        with open(
            os.path.join(a.out, f"{name}.theme.json"), "w", encoding="utf-8"
        ) as f:
            json.dump(record, f, indent=1)
        with open(
            os.path.join(a.out, f"{name}.console.txt"), "w", encoding="utf-8"
        ) as f:
            f.write(browse(a.browse, "console", "--errors"))
    print(
        f"design-evidence: shot {len(a.pages)} pages, {shots} screenshots into {a.out} "
        f"(engine browse, dark via data-theme)"
    )
    return 0 if shots else 1


def png_width(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return struct.unpack(">I", head[16:20])[0]


def digest(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def check(a):
    problems, present, dark_ok, paths = [], 0, 0, set()
    for page in a.pages:
        name = stem(page)
        for w, _ in WIDTHS:
            pair = {}
            for suffix in ("", "-dark"):
                p = os.path.join(a.out, f"{name}-{w}{suffix}.png")
                if not os.path.isfile(p):
                    problems.append(f"{name}: missing {os.path.basename(p)}")
                    continue
                got = png_width(p)
                if got is None:
                    problems.append(f"{name}: {os.path.basename(p)} is not a PNG")
                    continue
                if got % w:
                    problems.append(
                        f"{name}: {os.path.basename(p)} is {got} px wide, not a {w} viewport"
                    )
                    continue
                present += 1
                pair[suffix] = p
            if len(pair) == 2:
                if digest(pair[""]) == digest(pair["-dark"]):
                    problems.append(
                        f"{name}: dark {w} is byte-identical to light; the dark theme did not apply"
                    )
                else:
                    dark_ok += 1
        rec = os.path.join(a.out, f"{name}.theme.json")
        if os.path.isfile(rec):
            r = json.load(open(rec, encoding="utf-8"))
            paths.add(r.get("dark_path", "data-theme"))
            if r.get("light") and r.get("light") == r.get("dark"):
                problems.append(
                    f"{name}: computed colours are equal in light and dark; the page has no dark theme"
                )
        else:
            problems.append(f"{name}: no {name}.theme.json (run shoot)")
    for p in problems:
        print(f"problem: {p}")
    want = len(a.pages) * len(WIDTHS) * 2
    print(
        f"design-evidence: {len(a.pages)} pages, {present} of {want} screenshots present "
        f"(375/768/1440 light and dark), {dark_ok} of {len(a.pages) * len(WIDTHS)} dark shots differ from light, "
        f"{len(problems)} problems; dark shot via {' and '.join(sorted(paths)) or 'unknown'}"
    )
    if not a.pages:
        print("design-evidence: 0 pages given, nothing checked", file=sys.stderr)
        return 1
    return 1 if problems else 0


def debris_guard(run):
    """Run a shoot and report any tool folder it left in the repository."""
    root = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True
    ).stdout.strip() or os.getcwd()
    watch = [os.path.join(root, n) for n in (".gstack", ".playwright-mcp")]
    before = {w for w in watch if os.path.exists(w)}
    rc = run()
    left = [w for w in watch if os.path.exists(w) and w not in before]
    for w in left:
        shutil.rmtree(w, ignore_errors=True)
        print(f"design-evidence: removed {w}, left in the repository by the browser tool")
    return rc


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("shoot")
    s.add_argument("--base", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--browse", default=DEFAULT_BROWSE)
    s.add_argument("--chrome", default=None)
    s.add_argument("pages", nargs="*")
    c = sub.add_parser("check")
    c.add_argument("--out", required=True)
    c.add_argument("pages", nargs="*")
    a = ap.parse_args()
    if not a.pages:
        print("design-evidence: 0 pages given, nothing checked", file=sys.stderr)
        return 1
    try:
        return debris_guard(lambda: shoot(a)) if a.cmd == "shoot" else check(a)
    except (RuntimeError, subprocess.TimeoutExpired) as e:
        print(f"design-evidence: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
