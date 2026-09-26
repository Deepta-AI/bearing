# opd-voice

Transcription for the appointment line and OPD help desk of a multi-specialty
clinic chain in Hyderabad and Pune. Callers speak Hindi, Telugu, English and a
lot of Hindi-English mixed speech. Transcripts feed the booking system, so
doctor names, token numbers, dates and amounts have to come through correctly.

## Audio

Production audio is the telephony provider's call recording: 8 kHz, mono,
mu-law, often on speakerphone at a noisy front desk. Nothing is recorded
without the caller agreeing to the IVR consent prompt.

The line takes about 1,200 calls a day across the clinics, and an average
call is 3 minutes long; every call would be transcribed.

## Engine choice (open)

We have two candidate speech-to-text engines, `engine_a` (hosted API) and
`engine_b` (hosted API, cheaper per audio hour). Both were run on the same
100 clips; the outputs are in `data/calls/engine_a.jsonl` and
`data/calls/engine_b.jsonl`, keyed by clip `id`. The reference transcripts,
typed by the front-desk team, are in `data/calls/references.jsonl` and follow
`data/calls/CONVENTION.md`. The audio itself is not in this repository.

`scripts/quick_compare.py` is a first look someone did last week.

## Layout

- `app/transcribe.py`: the single function the booking service calls
- `data/calls/`: references and engine outputs
- `docs/vendor-notes.md`: what the vendors told us
