"""CRM access. With CRM_BASE_URL empty, reads and writes data/crm.json."""

import json
import os
import pathlib

DATA = pathlib.Path(os.environ.get("CRM_DATA_FILE", pathlib.Path(__file__).resolve().parent.parent / "data" / "crm.json"))


class CrmClient:
    def __init__(self, base_url: str = "", token: str = ""):
        self.base_url, self.token = base_url, token
        if base_url:
            raise NotImplementedError("the HTTP backend ships with the platform image")
        self._db = json.loads(DATA.read_text(encoding="utf-8"))

    def accounts(self) -> list[dict]:
        return self._db["accounts"]

    def account(self, account_id: str) -> dict:
        return next(a for a in self._db["accounts"] if a["id"] == account_id)

    def notes(self, account_id: str) -> list[dict]:
        return [n for n in self._db["notes"] if n["account_id"] == account_id]

    def add_note(self, account_id: str, author: str, text: str, at: str) -> dict:
        note = {"id": f"n_{len(self._db['notes']) + 1}", "account_id": account_id, "author": author, "text": text, "at": at}
        self._db["notes"].append(note)
        self._save()
        return note

    def delete_note(self, note_id: str) -> None:
        self._db["notes"] = [n for n in self._db["notes"] if n["id"] != note_id]
        self._save()

    def _save(self) -> None:
        DATA.write_text(json.dumps(self._db, indent=2), encoding="utf-8")
