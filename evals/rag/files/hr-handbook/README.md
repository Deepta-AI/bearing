# hr-handbook

`#ask-hr` Slack bot for Northwind Loom, a 60-person textile design studio.
Staff ask it about leave, holidays, expenses and so on. Today it replies
"Please ask the HR team" to everything (`hrbot/bot.py`).

The handbook lives in `handbook/` as markdown and is edited by the HR lead a
few times a year. Staff ask about 20 questions a day in `#ask-hr`.

## Code

- `hrbot/bot.py`: `answer(question, client) -> Reply`, called by the Slack
  handler (not in this repository).
- `hrbot/llm.py`: the model client interface. Production uses a hosted model
  behind `LLMClient`; tests use `FakeLLM`. There is no API key in CI.

## Data

- `handbook/`: the handbook. `handbook/old/` keeps previous versions for
  reference. `handbook/_hr-only/` holds working files for the HR team.
- `questions.md`: questions staff asked last month, with the answer the HR
  lead confirmed.

## Commands

    make test
