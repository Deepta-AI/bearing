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


if __name__ == "__main__":
    unittest.main()
