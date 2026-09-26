import json
import pathlib

db = json.loads((pathlib.Path(__file__).resolve().parent.parent / "data" / "crm.json").read_text())
for a in db["accounts"]:
    if a["last_contact"] < "2026-08-01":
        print(f"{a['id']} {a['name']} last contact {a['last_contact']}")
