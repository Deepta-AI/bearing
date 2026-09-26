import glob, os, re, sys
kit = sys.argv[1]
os.chdir(kit)
rows, bad = [], []
for n, line in enumerate(open("plugins/bearing/bin/pinned-packs.txt", encoding="utf-8"), 1):
    line = line.rstrip("\n")
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    f = line.split("|")
    if len(f) != 6:
        bad.append(f"pinned-packs.txt:{n}: {len(f)} fields, want 6")
        continue
    kind, src, pin = f[0], f[1], f[2]
    if kind in ("skill", "plugin", "cli", "clone"):
        if not re.fullmatch(r"[0-9a-f]{40}", pin):
            bad.append(f"pinned-packs.txt:{n}: {kind} {src} is not pinned to a full commit")
    elif kind in ("npm", "pypi"):
        if not re.fullmatch(r"\d+\.\d+\.\d+", pin):
            bad.append(f"pinned-packs.txt:{n}: {kind} {src} is not pinned to an exact version")
    else:
        bad.append(f"pinned-packs.txt:{n}: unknown kind {kind}")
    rows.append((kind, src, pin))
npm = {s: p for k, s, p in rows if k == "npm"}
pypi = {s.lower(): p for k, s, p in rows if k == "pypi"}

files = ["install.sh"] + sorted(glob.glob("plugins/*/bin/brg-*"))
for skill in sorted(glob.glob("plugins/*/skills/*/")):
    files.append(skill + "SKILL.md")
    for sub in ("references", "scripts"):
        files += sorted(p for p in glob.glob(f"{skill}{sub}/**/*", recursive=True)
                        if os.path.isfile(p) and "__pycache__" not in p)
files += ["plugins/bearing/skills/openapi-spec/templates/api-conformance.mk",
          "plugins/bearing/skills/mcp-server/templates/server-typescript.md",
          "plugins/bearing/skills/mcp-server/templates/server-python.md"]
EXEMPT_NPX = {"expo"}
# English words after npx or uvx in prose ("npx not found", "its npx installer").
PROSE = {"not", "installer", "is", "and", "or", "to", "the", "found", "call", "calls", "fetch", "tool"}
VER = r"(@[0-9A-Za-z.$<>{}_-]+)?"
checked = 0
for p in files:
    if not os.path.isfile(p):
        bad.append(f"{p}: listed for the scan but missing")
        continue
    text = re.sub(r"\s+", " ", open(p, encoding="utf-8", errors="replace").read())
    for m in re.finditer(r"\b(?:npx(?: --yes)?|pnpm dlx|bunx) (@?[a-z0-9][\w./-]*)" + VER, text):
        name, ver = m.group(1), (m.group(2) or "")[1:]
        if name in EXEMPT_NPX or name in PROSE:
            continue
        checked += 1
        if not ver:
            bad.append(f"{p}: unpinned npm fetch: {m.group(0)}")
        elif "$" in ver or "<" in ver:
            continue
        elif npm.get(name) != ver:
            bad.append(f"{p}: {name}@{ver} does not match pinned-packs.txt ({npm.get(name, 'no row')})")
    for m in re.finditer(r"\buvx ([a-z0-9][\w.-]*)(@[\w.]+)?", text):
        name, ver = m.group(1).lower(), (m.group(2) or "")[1:]
        if name in PROSE:
            continue
        checked += 1
        if pypi.get(name) != ver:
            bad.append(f"{p}: uvx {name}@{ver or '?'} does not match pinned-packs.txt ({pypi.get(name, 'no row')})")
    for m in re.finditer(r"--with ([A-Za-z0-9][\w.-]*)(==[\w.]+)?", text):
        checked += 1
        name, ver = m.group(1).lower(), (m.group(2) or "")[2:]
        if pypi.get(name) != ver:
            bad.append(f"{p}: --with {name}=={ver or '?'} does not match pinned-packs.txt ({pypi.get(name, 'no row')})")
    if re.search(r"(npx|dlx|bunx|uvx)[^`\n]*@latest", text):
        bad.append(f"{p}: @latest in a fetch")

readme = open("README.md", encoding="utf-8").read()
for k, s, p in rows:
    if k in ("npm", "pypi", "clone") and p not in readme:
        bad.append(f"README.md does not name the {k} pin {s} {p}")

for b in bad:
    print(b)
if not rows or checked == 0:
    print(f"nothing checked: {len(rows)} pins, {checked} fetches")
    sys.exit(1)
print(f"pins: {len(rows)} rows, {checked} fetches in {len(files)} files, {len(bad)} problems")
sys.exit(1 if bad else 0)
