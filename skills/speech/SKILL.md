---
name: speech
description: 'Builds speech features: transcription, diarisation, text-to-speech or a real-time voice agent with barge-in, measured by WER and latency. Use when asked to "transcribe calls", "build a voice agent" or "speech to text".'
argument-hint: "<batch|realtime|tts|analytics> <name> [--langs en,hi,te]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(wc -l:*), Bash(make:*), Bash(git status:*), Bash(uv run:*), Bash(npm run:*), Bash(ffprobe:*), Bash(python3 *skills/speech/scripts/wer.py*), Bash(python3 *skills/speech/scripts/latency_report.py*)
---

# speech

Speech features fail in two ways a demo hides: the transcript is wrong
for the accents and languages real callers use, and the agent is slow or
talks over people. This skill measures both before anyone calls it done:
word error rate per language on the product's own audio, and latency per
stage against a budget. The model call in the middle goes through the
gateway like any other.

Not this: phone numbers, TwiML and carrier setup on Twilio are
`twilio-voice-conversation-relay` (twilio-developer-kit, official
marketplace); this skill designs and measures what runs behind them.

## Inputs

- Job and name: `$1` and `$2`; if absent, asks which of batch
  transcription, real-time voice agent, text-to-speech only, or call
  analytics, in one question.
- Languages: `--langs`, else the solution doc `docs/genai/<name>-solution.md`;
  if neither, asks. Code-mixed speech (Hinglish, Tanglish) counts as its
  own language in every table.
- Audio: recordings the user names or `data/<name>/audio/`; if none,
  step 2 writes the recording plan and the eval runs on the first ten
  clips anyone records, marked `seed`.
- Gateway: `llm/` from `llm-gateway`; if absent, the model call sits
  behind one function and the gateway is a follow-up.
- Stack reference: `references/speech-stack.md` in this skill.

## Steps

**Decisions first.** Before building, run `tech-decision` for the keys
speech stack and llm provider and models. `tech-decision` asks only about
keys no accepted ADR, the request or the code already settles, one
question at a time, and records only what the user decides.

1. Job from `$1`, name from `$2`. Read `references/speech-stack.md` for
   the job's shape. State the audio path end to end: source (browser
   mic at 48 kHz, phone at 8 kHz mu-law, uploaded files), resampling,
   the model's expected rate, and where audio is stored or not.
2. Test set. At least 20 utterances per language from the product's own
   conditions (phone line, OPD noise, speakerphone), reference
   transcripts typed by a person with the convention written down
   (script for code-mixed speech, numbers as digits or words, fillers
   kept or dropped). Consent recorded per clip. Save as
   `evals/<name>/speech.jsonl` (`id`, `lang`, `ref`, `audio`).
3. Choose by measurement: run two or three candidate engines from the
   decision on the test set, write each engine's `hyp` into a copy of
   the file, and score each with
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/speech/scripts/wer.py" <file> --worst 5`.
   Record every engine's `speech-eval:` and `lang` lines in the ADR.
   Also count names, numbers and dates right (entity accuracy): WER
   hides a wrong phone number.
4. Build the job:
   - batch: a job queue (`background-jobs`), VAD chunking on silences, word
     timestamps, diarisation with speaker labels, retries per chunk,
     transcript stored with the engine and model version;
   - realtime: streaming recognition with partials, endpointing
     (silence 500 to 800 ms, tuned on the test set), the model call
     streamed through the gateway, TTS started on the first sentence,
     barge-in (caller speech over 300 ms during playback stops the
     audio and cancels the model stream; the history keeps only what
     the caller heard, and the interrupting speech becomes the next
     turn), echo cancellation on, no blocking I/O on the event loop, and a
     timing mark per turn (`speech_end`, `asr_final`, `llm_first_token`,
     `tts_first_audio`) written to `logs/<name>-turns.jsonl`;
   - tts: voice chosen by listeners from the target audience, three
     voices compared blind on the same ten sentences;
   - analytics: transcription as batch, then the analysis as an LLM
     feature with its own eval (`llm-eval`).
5. Latency (realtime): run twenty scripted turns and
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/speech/scripts/latency_report.py" logs/<name>-turns.jsonl`
   with the budget from the solution doc (default total p95 1500 ms).
   Over budget: fix the largest stage first (region, model size,
   streaming), rerun.
6. Safety and privacy: consent before recording, retention of audio
   (delete after the transcript is accepted unless a reason is
   written), PII redacted from stored transcripts, no audio or
   transcript bodies in logs, and scripted handling for anything the
   agent must not answer, with a test per script.
7. Agent behaviour (realtime): at least ten scenario tests driven by a
   simulated caller in text (changing their mind, interrupting,
   code-mixing, asking something out of scope), scored on task success.
8. Print the contract.

## Output contract

```
## Speech: <name> (<job>, <langs>)
audio path: <source> <rate> -> <model rate>, stored: <where | not stored>
test set: evals/<name>/speech.jsonl, <N> utterances (<per lang>), seed: yes | no
engines: <engine>: <speech-eval line> ; <engine>: <speech-eval line>
chosen: <engine> (ADR <id>), entity accuracy <x>/<y>
latency: <voice-latency line | not a realtime job>
barge-in: tested <n> interruptions, stopped <m> | not a realtime job
scenarios: <passed>/<run> | not run
privacy: consent yes, audio retention <rule>, transcript redaction <on>
```

## Gotchas

- Run the kit's scripts from the kit path while working. When the repo
  wants a make target or CI job for a check, copy the script into the
  repo's `scripts/` and point the target there; a target that names the
  kit's own path breaks on every other machine.
- WER from a vendor's page is on their data. Only the product's own
  audio counts, and a clean studio clip flatters every engine.
- Reference and hypothesis must follow one convention. Hinglish in
  Latin script scored against Devanagari output reads as 100% wrong.
  Report the output as delivered (what the downstream system receives)
  and, as a separate row, after normalising script and numbers; the
  normalisation is then work to build, not a free fix.
- Phone audio is 8 kHz. A model fed an upsampled call and evaluated on
  browser recordings will disappoint in production.
- Endpointing too short cuts callers off mid-sentence; too long feels
  dead. Tune it on the test set, not by feel.
- Barge-in without echo cancellation interrupts itself: the agent's own
  voice through the speaker counts as the caller.
- Regional-accent TTS voices can sound less natural than a neutral
  English voice to the same listeners. Let listeners choose.
- Total latency is what the caller hears. Three stages each within
  budget at p50 can still miss at p95; report p95.
