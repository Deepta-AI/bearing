"""Appointment reminders by SMS."""

import json
import os
import urllib.request


def send_reminder(phone, text, opener=urllib.request.urlopen):
    req = urllib.request.Request(
        "https://api.sms.example/v2/messages",
        data=json.dumps({"to": phone, "text": text}).encode(),
        headers={
            "Authorization": "Key " + os.environ["SMS_API_KEY"],
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with opener(req, timeout=10) as resp:
        return json.loads(resp.read())
