import unittest

from bot.loop import respond
from bot.session import Session
from tests.fakes import ScriptedModel, text, tool_call


class BotTest(unittest.TestCase):
    def test_faq_answer(self):
        model = ScriptedModel([
            tool_call("get_faq", {"topic": "delivery"}),
            text("Orders ship within 2 working days."),
        ])
        s = Session("conv_1", "c_201")
        reply = respond(s, "when will my stuff ship?", model)
        self.assertIn("2 working days", reply)
        self.assertEqual(len(model.requests), 2)

    def test_escalation(self):
        model = ScriptedModel([
            tool_call("escalate_to_human", {"summary": "wants invoice copy"}),
            text("A person will get back to you."),
        ])
        reply = respond(Session("conv_2", "c_201"), "I need a GST invoice copy", model)
        self.assertIn("person", reply)
