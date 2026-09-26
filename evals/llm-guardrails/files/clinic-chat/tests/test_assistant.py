import unittest

from chat.assistant import Session, reply
from tests.fakes import ScriptedModel


class AssistantTest(unittest.TestCase):
    def test_booking_question_gets_the_model_reply(self):
        model = ScriptedModel(
            ["Dr. Rao has a free slot at 10:30 today. Shall I book it?"]
        )
        out = reply(
            Session("conv_1", "p_501"), "Can I see Dr Rao today morning?", model
        )
        self.assertIn("10:30", out)

    def test_free_slots_reach_the_model(self):
        model = ScriptedModel(["ok"])
        reply(Session("conv_2", "p_501"), "any slots today?", model)
        system = model.requests[0]["system"]
        self.assertIn("10:30", system)
        self.assertIn("16:30", system)


if __name__ == "__main__":
    unittest.main()
