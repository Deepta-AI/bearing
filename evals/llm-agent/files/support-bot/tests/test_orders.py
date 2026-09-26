import unittest

from shop.orders import OrdersService
from tests.fakes import RecordingPayments, RecordingWarehouse


class OrdersTest(unittest.TestCase):
    def test_cancel_refunds_and_releases(self):
        pay, wh = RecordingPayments(), RecordingWarehouse()
        svc = OrdersService(pay, wh)
        svc.cancel_order("o_5001", "changed mind")
        self.assertEqual(svc.get_order("o_5001").status, "cancelled")
        self.assertEqual(pay.refunds, [("o_5001", 79900)])
        self.assertEqual(wh.released, ["o_5001"])

    def test_list_is_per_customer(self):
        svc = OrdersService(RecordingPayments(), RecordingWarehouse())
        self.assertEqual({o.id for o in svc.list_orders("c_202")}, {"o_5004", "o_5005"})
