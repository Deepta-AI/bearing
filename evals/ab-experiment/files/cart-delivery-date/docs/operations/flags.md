# Flags

| Flag | Kind | Owner | Since | Notes |
| --- | --- | --- | --- | --- |
| `new-search` | percentage rollout | search | 2026-06-02 | 20% while the index warms |
| `saved-carts` | percentage rollout | web | 2026-04-11 | at 100%, removal pending |

Flags are read from `config/flags.json` at process start; changing a
percentage needs a config change and a restart of the web pods.
