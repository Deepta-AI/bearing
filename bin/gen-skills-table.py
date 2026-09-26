#!/usr/bin/env python3
"""Regenerate the table between the markers in docs/SKILLS.md from each
skill's frontmatter, across the three Bearing plugins (bin/kit_paths.py). Fails when zero skills are found."""
import pathlib, re, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import kit_paths  # noqa: E402

root = pathlib.Path(__file__).resolve().parents[1]
rows = []
for d in kit_paths.skill_dirs():
    skill = d / "SKILL.md"
    plugin = kit_paths.plugin_of(d)
    text = skill.read_text(encoding="utf-8")
    m = re.search(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        sys.exit(f"no frontmatter: {skill}")
    fm = m.group(1)
    name = re.search(r"^name: (.+)$", fm, re.M).group(1).strip()
    desc = re.search(r"^description: (.+)$", fm, re.M).group(1).strip()
    # The one-line YAML forms the skills use: plain, 'single' ('' is a
    # quote) and "double" quoted; bin/skill-desc.py parses the same way.
    if len(desc) >= 2 and desc[0] == desc[-1] == "'":
        desc = desc[1:-1].replace("''", "'")
    elif len(desc) >= 2 and desc[0] == desc[-1] == '"':
        desc = desc[1:-1].replace('\\"', '"')
    # A skill hidden from the model is reached only by typing its name.
    typed = " (typed only)" if re.search(r"^disable-model-invocation: true", fm, re.M) else ""
    what, _, when = desc.partition(" Use when ")
    what = what.strip().rstrip(".").replace("|", "\\|")
    when = when.strip().rstrip(".").replace("|", "\\|")
    rows.append(f"| `{name}`{typed} | {plugin} | {what} | {when or 'see skill'} |")
if not rows:
    sys.exit("0 skills found")
doc = root / "docs" / "SKILLS.md"
body = doc.read_text(encoding="utf-8")
start, end = "<!-- skills-table:start -->", "<!-- skills-table:end -->"
if start not in body or end not in body:
    sys.exit("markers missing in docs/SKILLS.md")
table = "\n".join(["| Skill | Plugin | What it does | Use when |", "| --- | --- | --- | --- |", *rows])
head, rest = body.split(start, 1)
_, tail = rest.split(end, 1)
doc.write_text(f"{head}{start}\n{table}\n{end}{tail}", encoding="utf-8")
print(f"docs: {len(rows)} skills written to docs/SKILLS.md")
