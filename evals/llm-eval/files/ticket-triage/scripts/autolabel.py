"""Fill in labels for open tickets using the classifier, so we have more eval data.

Writes data/tickets.autolabelled.jsonl with resolved_category set from the
model's own answer and resolved_by = "autolabel".
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from triage.classify import TriageParseError, classify  # noqa: E402
from triage.llm import RecordedLLM  # noqa: E402
from triage.prompts import PROMPT_VERSION  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    client = RecordedLLM(PROMPT_VERSION)
    out = []
    for line in (ROOT / "data" / "tickets.jsonl").read_text().splitlines():
        t = json.loads(line)
        if t.get("resolved_category") is None:
            try:
                t["resolved_category"] = classify(t, client).strip().lower()
                t["resolved_by"] = "autolabel"
            except TriageParseError:
                continue
        out.append(t)
    (ROOT / "data" / "tickets.autolabelled.jsonl").write_text("\n".join(json.dumps(t) for t in out) + "\n")
    print(f"autolabel: {len(out)} tickets written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
