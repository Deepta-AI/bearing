# Speech stack reference

What each speech job needs, the engines worth putting in a bake-off, and
the numbers to start from. Vendors change quickly: check current
language support and pricing before the decision, and measure on the
product's own audio (step 3 of the skill) before choosing.

## Jobs

| Job | Shape | What to measure |
| --- | --- | --- |
| batch | files in, transcript with timestamps and speakers out | WER and CER per language, diarisation spot check, cost per audio hour |
| realtime | streaming in, streaming out, a model in the loop | p95 total latency, barge-in stops, task success |
| tts | text in, audio out | listener preference blind, time to first audio |
| analytics | batch transcript, then an LLM rubric | WER on the call audio, then the rubric's agreement with a person |

## Engines to compare

- Hosted streaming recognition: Deepgram, Google Speech-to-Text, Azure
  Speech, AssemblyAI; for Indian languages also Sarvam AI and Google's
  Indic models. Check code-mixed support explicitly.
- Self-hosted: Whisper large-v3 or large-v3-turbo through
  faster-whisper (CTranslate2); pyannote for diarisation; Silero VAD for
  chunking and endpointing.
- Text to speech: ElevenLabs, Cartesia, Azure neural voices, Google,
  Deepgram Aura; open models (Piper) where audio must stay local.
- Telephony platforms that bundle both ends: Twilio ConversationRelay
  (see `twilio-voice-conversation-relay`), Exotel and Plivo in India.

## Real-time loop

```
caller audio -> VAD / endpointing -> streaming ASR (partials, final)
  -> model call through the gateway (streamed)
  -> sentence splitter -> streaming TTS -> playback
barge-in: caller speech > 300 ms during playback
  -> stop playback, cancel model stream, keep the partial transcript
```

Starting budget for p95 (ms): endpointing plus ASR 300, model first
token 700, TTS first audio 300, total 1500. Put the voice server in the
same region as the telephony edge and the model endpoint.

## Test set conventions

- 20 or more utterances per language, recorded in the product's own
  conditions; code-mixed speech is its own language.
- One written convention for references: script per language, digits or
  words for numbers, fillers kept or dropped, names spelled as the
  customer writes them.
- Keep entity checks (names, numbers, dates, amounts) separate from WER.
