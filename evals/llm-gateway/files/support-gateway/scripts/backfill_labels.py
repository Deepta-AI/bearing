"""One-off: label last quarter's tickets for the analytics team.

python3 scripts/backfill_labels.py tickets.csv > labels.csv
"""

import csv
import sys

import anthropic

client = anthropic.Anthropic()

for row in csv.DictReader(open(sys.argv[1])):
    msg = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=16,
        system="Reply with one label: billing, refund_request, technical, account_access, other",
        messages=[{"role": "user", "content": row["text"]}],
    )
    print(f'{row["ticket_id"]},{msg.content[0].text.strip()}')
