# meeting-summaries

Summarises internal meeting transcripts for the Kitefield product team and
posts the summary to the meeting's Slack thread.

## What a good summary is (agreed with the product lead, 2026-08-18)

1. Three sections, in this order: `Decisions`, `Action items`, `Open questions`.
   An empty section says "None".
2. Every action item is `- <owner>: <task> (due <date>)`, or `(no date)` when
   the meeting set none. The owner is someone who spoke in the meeting. Never
   invent an owner or a date.
3. Every decision the meeting made is listed; nothing is listed as decided
   that was only discussed.
4. At most 180 words.
5. No opinions about the meeting or the people in it.

## Code

- `notes/summarise.py`: `summarise(meeting_id, transcript, client)`, model
  `claude-sonnet-5`, prompt in the module.
- `notes/llm.py`: `LLMClient` and `RecordedLLM`, which replays the summaries
  the production model wrote for the ten transcripts in `data/transcripts/`
  (`fixtures/recorded_summaries.jsonl`, captured 2026-09-10). There is no API
  key in CI or on dev laptops; the team key lives in the deploy environment
  only.

## Commands

    make test
