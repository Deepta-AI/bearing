"""Client for MailBlast, the newsletter provider (a processor).

MailBlast keeps its own copy of every contact we push: email, name and the
list membership. Their API (docs: /v2/contacts):

    PUT    /v2/contacts/{email}   create or update a contact (subscribed)
    POST   /v2/contacts/{email}/unsubscribe
    DELETE /v2/contacts/{email}   erase the contact and its history
"""

import json
import os
import urllib.request


class MailBlastClient:
    def __init__(self, base_url=None, api_key=None):
        self.base_url = base_url or os.environ.get("MAILBLAST_URL", "https://api.mailblast.example")
        self.api_key = api_key or os.environ.get("MAILBLAST_API_KEY", "")

    def _call(self, method, path, body=None):
        req = urllib.request.Request(
            self.base_url + path,
            method=method,
            data=json.dumps(body).encode() if body is not None else None,
            headers={"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status

    def upsert_contact(self, email, name):
        return self._call("PUT", f"/v2/contacts/{email}", {"name": name, "subscribed": True})

    def unsubscribe(self, email):
        return self._call("POST", f"/v2/contacts/{email}/unsubscribe")

    def delete_contact(self, email):
        return self._call("DELETE", f"/v2/contacts/{email}")


class FakeMailBlast:
    """In-memory stand-in for tests."""

    def __init__(self):
        self.contacts = {}
        self.calls = []

    def upsert_contact(self, email, name):
        self.calls.append(("upsert", email))
        self.contacts[email] = {"name": name, "subscribed": True}

    def unsubscribe(self, email):
        self.calls.append(("unsubscribe", email))
        if email in self.contacts:
            self.contacts[email]["subscribed"] = False

    def delete_contact(self, email):
        self.calls.append(("delete", email))
        self.contacts.pop(email, None)
