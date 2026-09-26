# clinic-chat

The chat assistant on the Anvaya Clinics patient app (a fictional clinic
chain used in this repository). A signed-in patient asks about timings,
fees and appointments and can book or move an appointment. Launches in
three clinics first, then all twelve (about 3,000 chats a day expected).

Python 3.12+, standard library only. The model is reached through
`chat/llm.py` (`ModelClient`); the production client is in the platform
image. CI has no network and no API key: tests use `tests/fakes.py`.

- `chat/assistant.py`: builds the prompt and returns the reply
- `chat/schedule.py`: today's appointment book per doctor
- `chat/patients.py`: patient records
- `docs/policy/assistant-policy.md`: what the assistant may and may not do

    make check
