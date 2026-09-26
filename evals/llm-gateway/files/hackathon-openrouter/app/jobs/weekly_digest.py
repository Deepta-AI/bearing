"""Friday job: one digest email per team."""

import time

import anthropic

from app.mailer import render_digest, send_email

client = anthropic.Anthropic()


def run_digest(team: str, week: str, notes: list[str], to: str) -> None:
    for attempt in range(4):
        try:
            msg = client.messages.create(
                model="claude-sonnet-5",
                max_tokens=1500,
                system="Write a weekly digest of these standup notes: wins, blockers, risks.",
                messages=[{"role": "user", "content": "\n\n".join(notes)}],
            )
            send_email(to, f"{team} weekly digest {week}", render_digest(team, week, msg.content[0].text))
            return
        except Exception:
            time.sleep(2 ** attempt)
    raise RuntimeError(f"digest failed for {team} {week}")
