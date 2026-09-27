import json
import os
import tempfile
import unittest

from notes import store


class StoreTest(unittest.TestCase):
    def test_add_then_load(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "n.json")
            store.add("buy milk", p)
            self.assertEqual(store.load(p), [{"id": 1, "text": "buy milk"}])

    def test_notes_reads_a_0_1_store(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "n.json")
            with open(p, "w") as f:
                json.dump(["old one", {"id": 2, "text": "new one"}], f)
            self.assertEqual(store.notes(p), [{"id": 1, "text": "old one"}, {"id": 2, "text": "new one"}])


if __name__ == "__main__":
    unittest.main()
