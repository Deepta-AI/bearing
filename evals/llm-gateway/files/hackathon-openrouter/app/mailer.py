"""Sends email through the SMTP relay. Slow and occasionally times out."""

import os
import smtplib
from email.message import EmailMessage


def send_email(to: str, subject: str, body: str) -> None:
    msg = EmailMessage()
    msg["From"] = os.environ.get("DIGEST_FROM", "digest@standup-scribe.example")
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(body)
    with smtplib.SMTP(os.environ.get("SMTP_HOST", "localhost"), timeout=10) as s:
        s.send_message(msg)


def render_digest(team: str, week: str, summary: str) -> str:
    return f"Weekly digest for {team}, week {week}\n\n{summary}\n"
