"""Quick comparison of the two engines (first look, not reviewed).

Only the English clips for now: the Hindi and Telugu lines printed as
boxes in my terminal, so I skipped them.
"""

import json

refs = {}
for line in open("data/calls/references.jsonl", encoding="utf-8"):
    row = json.loads(line)
    if row["lang"] == "en":
        refs[row["id"]] = row["ref"]

for engine in ("engine_a", "engine_b"):
    right = total = 0
    for line in open(f"data/calls/{engine}.jsonl", encoding="utf-8"):
        row = json.loads(line)
        if row["id"] not in refs:
            continue
        ref = refs[row["id"]].split()
        hyp = row["hyp"].split()
        right += sum(1 for r, h in zip(ref, hyp) if r == h)
        total += len(ref)
    print(f"{engine}: word accuracy {right / total:.1%} on {len(refs)} English clips")
