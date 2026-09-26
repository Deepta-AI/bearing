import unittest

from crm.client import CrmClient


class ClientTest(unittest.TestCase):
    def test_reads_sample_data(self):
        c = CrmClient()
        self.assertEqual(len(c.accounts()), 3)
        self.assertEqual([n["id"] for n in c.notes("acc_301")], ["n_1", "n_2"])
