# support-bot

The chat assistant in the shop's mobile app (Help tab). A signed-in
customer chats with it; today it answers FAQ questions and hands over to a
person when it cannot help.

Python 3.12+, standard library only. The model is reached through
`bot/llm.py` (`ModelClient`); the production client lives in the platform
image. Tests use `tests/fakes.py` and never call a provider.

- `bot/loop.py`: the conversation loop
- `bot/tools.py`: functions the model can call
- `bot/session.py`: one chat session (the signed-in customer and the history)
- `shop/orders.py`: the orders service the rest of the app uses
- `docs/ops/cancellations.md`: how cancellations work today

    make check
