# Build Weekend demo notes

- Demo day is Saturday. Judges get the demo laptop for 20 minutes each;
  expect a few hundred model calls over the day.
- The organisers give every team one OpenRouter key with USD 25 of
  credit. It is handed over on Friday evening as an environment
  variable. There are no Anthropic or OpenAI keys on the demo laptop.
- All model calls on the day must go through OpenRouter. Use the
  Anthropic models through it (`anthropic/claude-sonnet-5`,
  `anthropic/claude-haiku-4-5`).
- Last week's dry run: the weekly digest job billed the model three
  times for the same team's digest and sent two emails, because the
  mail server was slow to answer.
