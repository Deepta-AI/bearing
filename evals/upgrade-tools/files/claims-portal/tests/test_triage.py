import unittest

from claims.triage import queue_for


class QueueFor(unittest.TestCase):
    def test_fraud_goes_to_investigation(self):
        self.assertEqual(queue_for({"amount": 10, "fraud_flag": True}), "investigation")

    def test_small_complete_claim_is_fast_tracked(self):
        self.assertEqual(queue_for({"amount": 50_000, "documents_complete": True}), "fast-track")

    def test_incomplete_claim_is_standard(self):
        self.assertEqual(queue_for({"amount": 100, "documents_complete": False}), "standard")


if __name__ == "__main__":
    unittest.main()
