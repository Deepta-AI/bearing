# Contributing

1. After cloning, run `make setup` once. It points git at the hooks in
   `.githooks/`: commit-msg checks the subject, pre-commit blocks `.env`
   files and obvious secrets, pre-push refuses pushes to `main` and runs
   `make check`.
2. Every change starts on a task branch, `feature/PAY-123-ShortName`, and
   every commit subject on it ends with the task id: `fix(batch): round
   holds [PAY-123]`.
3. Open a merge request into `main`; CI runs `make check`.
