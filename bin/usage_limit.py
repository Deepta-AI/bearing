"""usage_limit: tell a session refused for the plan's usage or rate limit from
one that failed, for the eval runners (trigger-eval, harness-eval,
skill-evals-run).

A refused session is not a result: once one says the limit is hit, every
session after it is refused too, so a runner stops starting sessions, marks
what it did not run as "not run (usage limit)" and exits LIMITED. The
scoreboard leaves those out instead of counting them as failures, so a
limited run never reads as a regression or, the week after, as a recovery.
On 22 Oct 2026 the first weekly run hit "You've hit your session limit"
after 547 trigger sessions, and the harness and skill evals that followed
all "failed".
"""

import re
import threading

LIMITED = 3  # exit code: stopped at the usage limit; what ran is recorded

_PATTERN = re.compile(
    r"hit your (?:\w+ )?limit|usage limit|session limit|rate[ _-]?limit(?!er)|"
    r"too many requests|\b429\b|overloaded_error|quota exceeded",
    re.I,
)


def is_limit(text):
    """True when a session's error or result text is a usage or rate limit."""
    return bool(text) and bool(_PATTERN.search(str(text)))


class Stop:
    """Set once any session hits the limit; runners check it before starting
    another session. Thread-safe."""

    def __init__(self):
        self._e = threading.Event()
        self.reason = ""

    def hit(self, reason):
        if not self._e.is_set():
            self.reason = str(reason)[:200]
        self._e.set()

    def __bool__(self):
        return self._e.is_set()
