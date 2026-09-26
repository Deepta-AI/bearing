import unittest

from app.notify import email_customer
from app.store import NotFound, seeded
from tests.fakes import FakeMailer


class StoreTest(unittest.TestCase):
    def test_note_is_added(self):
        store = seeded()
        store.add_note("T-2001", "checked photos")
        self.assertEqual(store.get_ticket("T-2001").notes, ["checked photos"])

    def test_unknown_ticket(self):
        with self.assertRaises(NotFound):
            seeded().get_ticket("T-9999")

    def test_existing_refund_is_counted(self):
        self.assertEqual(seeded().refunded_paise("o_1004"), 129900)

    def test_email_goes_to_the_customer_on_record(self):
        mailer = FakeMailer()
        email_customer(seeded(), mailer, "c_101", "Your refund", "Done.")
        self.assertEqual(mailer.sent[0][0], "asha.verma@example.com")


if __name__ == "__main__":
    unittest.main()
