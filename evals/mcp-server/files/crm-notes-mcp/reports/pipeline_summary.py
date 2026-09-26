import json
import pathlib

db = json.loads((pathlib.Path(__file__).resolve().parent.parent / "data" / "crm.json").read_text())
by_tier = {}
for a in db["accounts"]:
    by_tier[a["tier"]] = by_tier.get(a["tier"], 0) + a["arr_inr"]
for tier, arr in sorted(by_tier.items()):
    print(f"{tier}: INR {arr:,}")
