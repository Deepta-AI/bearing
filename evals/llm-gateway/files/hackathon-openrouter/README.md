# standup-scribe

Turns a team's async standup notes into summaries, tags, a chat helper
and a weekly digest email. Built for the Build Weekend hackathon; see
`docs/hackathon.md` for the demo setup.

- `app/summarize.py`: one-paragraph summary of a standup note.
- `app/classify.py`: labels a note as blocked, on_track or at_risk.
- `app/tagging.py`: topic tags for search.
- `app/chat.py`: "ask your standups" chat helper.
- `app/jobs/weekly_digest.py`: Friday digest email per team.

Run the tests with `make test` (offline; no API key needed).
