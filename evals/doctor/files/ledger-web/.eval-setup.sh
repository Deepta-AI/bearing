#!/usr/bin/env bash
# Build the starting state: a clone where husky (v8) was installed, so
# core.hooksPath is .husky and husky's own .husky/_ helper exists untracked.
set -eu
rm -f .eval-setup.sh
chmod +x .githooks/commit-msg .githooks/pre-commit .githooks/pre-push .githooks/install.sh .husky/pre-commit .husky/commit-msg .husky/pre-push
git init -q -b main
git add -A
git -c user.name=Dev -c user.email=dev@example.com commit -q -m "chore: ledger-web on the team standard"
git config core.hooksPath .husky
mkdir -p .husky/_
printf '*\n' > .husky/_/.gitignore
cat > .husky/_/husky.sh <<'SH'
#!/usr/bin/env sh
if [ -z "$husky_skip_init" ]; then
  readonly hook_name="$(basename -- "$0")"
  readonly husky_skip_init=1
  export husky_skip_init
  sh -e "$0" "$@"
  exitCode="$?"
  exit $exitCode
fi
SH
git checkout -q -b feature/LED-212-EntryReversal
