# support-assist

Assistant features in the Harbourline customer support console: a chat
helper for agents, automatic ticket tags, ticket summaries and triage.

Prompts are moving into `prompts/<name>/v<N>.md`, loaded by
`src/prompts/index.js`. Each prompt folder has a CHANGELOG with the eval
score of each version on `evals/<name>/`. Not every feature has moved yet.

Node 22, no dependencies. The model client (`src/llm.js`) is injected;
tests use a fake.

    npm test
