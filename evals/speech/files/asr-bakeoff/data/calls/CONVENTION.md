# How the reference transcripts are typed

Agreed with the front-desk team before transcription started.

- Hindi is written in Devanagari, Telugu in Telugu script, English in Latin.
- Hindi-English mixed speech (lang `hi-en`) is written entirely in Latin
  script, the way callers type it on WhatsApp ("mera appointment kal hai").
- All numbers are written as digits: token numbers, times, days, amounts
  ("token number 47", "500 rupees", "10 baje").
- Lower case, no punctuation.
- Fillers (umm, haan, accha as a filler) are dropped.
- Doctor names are spelled the way the clinic's roster spells them.

Each clip in `references.jsonl` has `id`, `lang`, `ref`, the `audio` file
name, its `sample_rate`, `source` and whether consent was recorded.
