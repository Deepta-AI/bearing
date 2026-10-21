import unittest

from receipts.render import WIDTH, render


class RenderTest(unittest.TestCase):
    def test_total_is_the_sum_of_the_lines(self):
        out = render("O-17", [("Tea", 2, 12000), ("Cake", 1, 25050)])
        self.assertIn("Receipt O-17", out)
        self.assertTrue(out.rstrip().endswith("490.50"))

    def test_lines_fit_the_width(self):
        out = render("O-18", [("A very long product name indeed", 3, 999)])
        for row in out.splitlines():
            self.assertLessEqual(len(row), WIDTH)
