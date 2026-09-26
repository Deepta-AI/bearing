import json
import pathlib
import unittest

from intake.pipeline import Intake
from intake.store import PayablesQueue
from intake.vendors import VendorDirectory
from tests.fakes import FakeMailer, ScriptedModel, text, tool_call

SAMPLES = pathlib.Path(__file__).resolve().parent.parent / "samples"

KAVERI_0917 = {
    "vendor_gstin": "29ABCDE1234F1Z5",
    "invoice_number": "KOS/26-27/0917",
    "invoice_date": "2026-09-17",
    "due_date": "2026-10-17",
    "total_paise": 663160,
    "bank_account": "001234567890",
    "ifsc": "EXMP0001234",
}


class PipelineTest(unittest.TestCase):
    def test_clean_invoice_is_accepted(self):
        model = ScriptedModel(
            [
                tool_call("lookup_vendor", {"gstin": "29ABCDE1234F1Z5"}),
                text(json.dumps(KAVERI_0917)),
            ]
        )
        queue = PayablesQueue()
        intake = Intake(model, VendorDirectory(), FakeMailer(), queue)
        doc = (SAMPLES / "invoice-kaveri-0917.txt").read_text(encoding="utf-8")
        result = intake.process(doc, uploaded_by="u_finance_01")
        self.assertEqual(result["status"], "accepted")
        self.assertEqual(queue.accepted[0]["total_paise"], 663160)

    def test_missing_due_date_emails_vendor(self):
        partial = dict(KAVERI_0917, due_date=None)
        mailer = FakeMailer()
        model = ScriptedModel(
            [
                tool_call(
                    "email_vendor",
                    {
                        "to": "billing@kaveri-office.example",
                        "subject": "Due date",
                        "body": "Please confirm the due date for KOS/26-27/0917.",
                    },
                ),
                tool_call(
                    "flag_for_review", {"reason": "due date missing"}, call_id="tu_2"
                ),
                text(json.dumps(partial)),
            ]
        )
        queue = PayablesQueue()
        result = Intake(model, VendorDirectory(), mailer, queue).process(
            "invoice without due date", "u_finance_01"
        )
        self.assertEqual(result["status"], "review")
        self.assertEqual(mailer.sent[0][0], "billing@kaveri-office.example")


if __name__ == "__main__":
    unittest.main()
