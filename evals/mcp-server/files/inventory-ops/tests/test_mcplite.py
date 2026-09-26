import sys
import unittest

from mcplite.client import StdioClient


class McpliteTest(unittest.TestCase):
    def setUp(self):
        self.client = StdioClient([sys.executable, "-m", "tests.example_server"])
        self.client.initialize()

    def tearDown(self):
        self.client.close()

    def test_list_and_call(self):
        self.assertEqual([t["name"] for t in self.client.list_tools()], ["echo_text"])
        r = self.client.call_tool("echo_text", {"text": "hi"})["result"]
        self.assertFalse(r["isError"])
        self.assertEqual(r["structuredContent"], {"text": "hi"})

    def test_tool_error(self):
        r = self.client.call_tool("echo_text", {"text": "x" * 101})["result"]
        self.assertTrue(r["isError"])
        self.assertIn("invalid_input", r["content"][0]["text"])

    def test_unknown_tool(self):
        self.assertIn("error", self.client.call_tool("nope", {}))


if __name__ == "__main__":
    unittest.main()
