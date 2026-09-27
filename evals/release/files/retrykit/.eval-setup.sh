#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the final
# working tree of main; the earlier versions are written here.
#   v1.3.0 (annotated), 2026-07-14: exports retry, backoff, retryDelay;
#     retry takes a `timeout` option
#   then: jitter (feat), retryDelay removed (refactor, no breaking marker),
#     no retry on 4xx except 429 (fix), `timeout` renamed `timeoutMs`
#     (refactor, no breaking marker; the same commit moves withTimeout to
#     Promise.withResolvers, which Node 18 and 20 lack, while engines still
#     says >=18 and CI tests only node:22), a test commit
# The local env file (stored as dotenv.local.evalfile) is ignored by git
# but stays on disk; .npmignore exists, so npm does not read .gitignore and
# would pack it.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do cp "$final/$p" "$p"; done; }

# ---- v1.3.0 -------------------------------------------------------------
cat > src/backoff.js <<'EOF'
/**
 * Delay before retry number `attempt` (1-based): baseMs doubled per attempt,
 * capped at maxMs.
 */
export function backoff(attempt, { baseMs = 100, maxMs = 5000 } = {}) {
  return Math.min(maxMs, baseMs * 2 ** (attempt - 1));
}
EOF
cat > src/delay.js <<'EOF'
import { backoff } from './backoff.js';

/** The delay retry waits before attempt `attempt` with these options. */
export function retryDelay(attempt, options = {}) {
  return backoff(attempt - 1, options);
}
EOF
cat > src/index.js <<'EOF'
export { retry } from './retry.js';
export { backoff } from './backoff.js';
export { retryDelay } from './delay.js';
EOF
cat > src/retry.js <<'EOF'
import { backoff } from './backoff.js';

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function withTimeout(promise, ms) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`attempt timed out after ${ms} ms`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

/**
 * Call fn until it resolves or `retries` retries are spent.
 * Options: retries (3), timeout per attempt in ms (10000), baseMs, maxMs.
 */
export async function retry(fn, options = {}) {
  const { retries = 3, timeout = 10000, ...delay } = options;
  for (let attempt = 0; ; attempt++) {
    try {
      return await withTimeout(Promise.resolve().then(fn), timeout);
    } catch (err) {
      if (attempt >= retries) throw err;
      await sleep(backoff(attempt + 1, delay));
    }
  }
}
EOF
cat > index.d.ts <<'EOF'
export interface BackoffOptions {
  /** First delay in milliseconds (default 100). */
  baseMs?: number;
  /** Largest delay in milliseconds (default 5000). */
  maxMs?: number;
}

export interface RetryOptions extends BackoffOptions {
  /** Retries after the first attempt (default 3). */
  retries?: number;
  /** Per-attempt timeout in milliseconds (default 10000). */
  timeout?: number;
}

export function backoff(attempt: number, options?: BackoffOptions): number;

export function retryDelay(attempt: number, options?: BackoffOptions): number;

export function retry<T>(fn: () => T | Promise<T>, options?: RetryOptions): Promise<T>;
EOF
cat > test/backoff.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { backoff, retryDelay } from '../src/index.js';

test('doubles per attempt and caps at maxMs', () => {
  assert.deepEqual([1, 2, 3, 4].map((a) => backoff(a, { baseMs: 100, maxMs: 500 })), [100, 200, 400, 500]);
});

test('retryDelay is the backoff before that attempt', () => {
  assert.equal(retryDelay(4), 400);
});
EOF
cat > test/retry.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { retry } from '../src/index.js';

const fast = { baseMs: 1, maxMs: 2 };

test('retries until the call succeeds', async () => {
  let calls = 0;
  const out = await retry(async () => {
    calls++;
    if (calls < 3) throw new Error('flaky');
    return 'ok';
  }, fast);
  assert.equal(out, 'ok');
  assert.equal(calls, 3);
});
EOF

git init -q -b main
at "2026-07-14 11:00:00"
git add -A
git commit -q -m "chore(release): v1.3.0"
git tag -a v1.3.0 -m "v1.3.0"

# ---- feat: jitter ---------------------------------------------------------
restore src/backoff.js
python3 - <<'PY'
p = "index.d.ts"
s = open(p).read()
s = s.replace("  maxMs?: number;\n}", "  maxMs?: number;\n  /** Randomise each delay between 0 and the computed value. */\n  jitter?: boolean;\n  /** Source of randomness for jitter (default Math.random). */\n  random?: () => number;\n}", 1)
open(p, "w").write(s)
p = "test/backoff.test.js"
s = open(p).read()
s += """
test('jitter stays between 0 and the capped delay', () => {
  assert.equal(backoff(3, { baseMs: 100, jitter: true, random: () => 0.5 }), 200);
  assert.equal(backoff(3, { baseMs: 100, jitter: true, random: () => 0 }), 0);
});
"""
open(p, "w").write(s)
PY
at "2026-08-04 15:20:00"
git add -A
git commit -q -m "feat: add jitter option to backoff"

# ---- refactor: retryDelay removed ----------------------------------------
git rm -q src/delay.js
restore src/index.js test/backoff.test.js
python3 - <<'PY'
p = "index.d.ts"
s = open(p).read()
s = s.replace("export function retryDelay(attempt: number, options?: BackoffOptions): number;\n\n", "")
open(p, "w").write(s)
PY
at "2026-08-12 10:40:00"
git add -A
git commit -q -m "refactor: fold retryDelay into backoff"

# ---- fix: no retry on 4xx except 429 --------------------------------------
python3 - <<'PY'
p = "src/retry.js"
s = open(p).read()
s = s.replace("/**\n * Call fn", """// A client error will fail the same way again; 429 asks us to come back later.
function defaultShouldRetry(err) {
  const status = err && err.status;
  if (typeof status === 'number' && status >= 400 && status < 500) return status === 429;
  return true;
}

/**
 * Call fn""")
s = s.replace(" * Options: retries (3), timeout per attempt in ms (10000), baseMs, maxMs.", " * Options: retries (3), timeout per attempt in ms (10000), baseMs, maxMs,\n * jitter, shouldRetry(err).")
s = s.replace("const { retries = 3, timeout = 10000, ...delay } = options;", "const { retries = 3, timeout = 10000, shouldRetry = defaultShouldRetry, ...delay } = options;")
s = s.replace("if (attempt >= retries) throw err;", "if (attempt >= retries || !shouldRetry(err)) throw err;")
open(p, "w").write(s)
p = "index.d.ts"
s = open(p).read()
s = s.replace("  timeout?: number;\n}", "  timeout?: number;\n  /** Return false to stop retrying on this error. */\n  shouldRetry?: (err: unknown) => boolean;\n}")
open(p, "w").write(s)
PY
cp "$final/test/retry.test.js" test/retry.test.js
python3 - <<'PY'
p = "test/retry.test.js"
s = open(p).read()
s = s[: s.index("test('times out a hung attempt'")].rstrip() + "\n"
open(p, "w").write(s)
PY
at "2026-08-27 18:05:00"
git add -A
git commit -q -m "fix: do not retry 4xx responses except 429"

# ---- refactor: timeout renamed timeoutMs ----------------------------------
restore src/retry.js index.d.ts
at "2026-09-09 12:30:00"
git add -A
git commit -q -m "refactor: rename the timeout option to timeoutMs for clarity"

# ---- test -------------------------------------------------------------------
restore test/retry.test.js
at "2026-09-15 09:10:00"
git add -A
git commit -q -m "test: cover the per-attempt timeout"

cp -a "$final/." .
rm -f .eval-setup.sh .eval-branch
if [ -n "$(git status --porcelain)" ]; then
  echo "setup: final tree differs from the last commit" >&2
  git status --porcelain >&2
  exit 1
fi
rm -r "$final"
