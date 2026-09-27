import csv
import os
import tempfile
import unittest
from datetime import datetime, timezone

from export.job import COLUMNS, export_hour, output_path
from export.worker import hours_to_check, run_pass
from tests.helpers import make_db


def read(path):
    with open(path, newline="") as f:
        return list(csv.reader(f))


class ExportHourTest(unittest.TestCase):
    def test_writes_rows_in_order_with_region(self):
        db, _ = make_db([
            ("e2", "acc_2", "click", "2026-09-20T13:05:00Z"),
            ("e1", "acc_1", "view", "2026-09-20T13:01:00Z"),
            ("e3", "acc_9", "view", "2026-09-20T14:00:00Z"),
        ])
        out = tempfile.mkdtemp()
        self.assertEqual(export_hour(db, "2026-09-20T13", out), 2)
        rows = read(output_path(out, "2026-09-20T13"))
        self.assertEqual(rows[0], COLUMNS)
        self.assertEqual([r[0] for r in rows[1:]], ["e1", "e2"])
        self.assertEqual([r[2] for r in rows[1:]], ["eu", "us"])

    def test_duplicate_deliveries_exported_once(self):
        db, _ = make_db([
            ("d1", "acc_1", "view", "2026-09-20T10:01:00Z"),
            ("d1", "acc_1", "view", "2026-09-20T10:01:00Z"),
            ("d2", "acc_1", "view", "2026-09-20T10:02:00Z"),
        ])
        out = tempfile.mkdtemp()
        self.assertEqual(export_hour(db, "2026-09-20T10", out), 2)

    def test_unknown_account_region(self):
        db, _ = make_db([("u1", "acc_404", "view", "2026-09-20T09:00:00Z")])
        out = tempfile.mkdtemp()
        export_hour(db, "2026-09-20T09", out)
        self.assertEqual(read(output_path(out, "2026-09-20T09"))[1][2], "unknown")


class WorkerTest(unittest.TestCase):
    def test_checks_the_24_hours_before_the_current_one(self):
        hours = hours_to_check(datetime(2026, 9, 20, 15, 30, tzinfo=timezone.utc))
        self.assertEqual(len(hours), 24)
        self.assertEqual(hours[0], "2026-09-20T14")
        self.assertEqual(hours[-1], "2026-09-19T15")

    def test_skips_hours_already_written(self):
        db, _ = make_db([("w1", "acc_1", "view", "2026-09-20T14:10:00Z")])
        out = tempfile.mkdtemp()
        now = datetime(2026, 9, 20, 15, 30, tzinfo=timezone.utc)
        self.assertEqual(run_pass(db, out, now), 24)
        self.assertEqual(run_pass(db, out, now), 0)
        self.assertTrue(os.path.exists(output_path(out, "2026-09-20T14")))


if __name__ == "__main__":
    unittest.main()
