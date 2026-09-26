#!/usr/bin/env python3
"""Regenerate the table between the markers in docs/SKILLS.md from each
skill's frontmatter. Fails when zero skills are found."""
import pathlib, re, sys

root = pathlib.Path(__file__).resolve().parents[1]
rows = []
for skill in sorted((root / "skills").glob("*/SKILL.md")):
    text = skill.read_text(encoding="utf-8")
    m = re.search(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        sys.exit(f"no frontmatter: {skill}")
    fm = m.group(1)
    name = re.search(r"^name: (.+)$", fm, re.M).group(1).strip()
    desc = re.search(r"^description: (.+)$", fm, re.M).group(1).strip()
    cmd = "command" if re.search(r"^disable-model-invocation: true", fm, re.M) else "auto"
    what, _, when = desc.partition(" Use when ")
    rows.append(f"| `{name}` | {what.strip().rstrip('.')} | {when.strip().rstrip('.') or 'see skill'} | {cmd} |")
if not rows:
    sys.exit("0 skills found")
doc = root / "docs" / "SKILLS.md"
body = doc.read_text(encoding="utf-8")
start, end = "<!-- skills-table:start -->", "<!-- skills-table:end -->"
if start not in body or end not in body:
    sys.exit("markers missing in docs/SKILLS.md")
table = "\n".join(["| Skill | What it does | Use when | Invocation |", "| --- | --- | --- | --- |", *rows])
head, rest = body.split(start, 1)
_, tail = rest.split(end, 1)
doc.write_text(f"{head}{start}\n{table}\n{end}{tail}", encoding="utf-8")
print(f"docs: {len(rows)} skills written to docs/SKILLS.md")
