from notify.batch import run
from notify.provider import Provider, ProviderTimeout
from notify.sender import notify_payout

PAYOUT = {"id": "po_1", "email": "partner@example.com", "amount_paise": 125000}


class FlakyTransport:
    def __init__(self, timeouts):
        self.timeouts = timeouts
        self.calls = []

    def __call__(self, payload, headers, timeout_s):
        self.calls.append((payload, headers))
        if len(self.calls) <= self.timeouts:
            raise ProviderTimeout()
        return f"msg_{len(self.calls)}"


def test_sends_once_when_the_provider_answers():
    t = FlakyTransport(0)
    assert notify_payout(Provider(t, 2.0), PAYOUT, max_retries=3) == "msg_1"
    assert len(t.calls) == 1


def test_retries_after_a_timeout():
    t = FlakyTransport(2)
    assert notify_payout(Provider(t, 2.0), PAYOUT, max_retries=3) == "msg_3"
    assert len(t.calls) == 3


def test_gives_up_after_the_last_retry():
    t = FlakyTransport(10)
    assert notify_payout(Provider(t, 2.0), PAYOUT, max_retries=1) is None
    assert len(t.calls) == 2


def test_batch_counts_sent_and_failed():
    t = FlakyTransport(0)
    assert run([PAYOUT, dict(PAYOUT, id="po_2")], Provider(t, 2.0)) == (2, 0)
