# booking-bot

Phone agent that books, moves and cancels clinic appointments. Calls arrive
from the telephony provider as an 8 kHz mu-law media stream over a websocket;
`agent/loop.py` runs one `CallSession` per call: voice activity detection,
speech recognition, the model call, text to speech and playback.

Each turn is logged to `logs/turns.jsonl` with its timing marks in
milliseconds (`speech_end`, `asr_final`, `llm_first_token`, `tts_first_audio`)
plus `overlap_ms`, how long the caller was speaking while the agent's audio
was playing.

The last 60 turns from the pilot (12 test calls made by the clinic staff on
Tuesday) are in `logs/turns.jsonl`.

## Run the tests

    make test
