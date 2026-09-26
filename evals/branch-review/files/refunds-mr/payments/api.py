from payments import orders


def get_order(conn, principal, order_id):
    """GET /orders/{id}"""
    order = orders.get_order(conn, order_id)
    if order is None or order["merchant_id"] != principal.merchant_id:
        return 404, {"error": "order not found"}
    return 200, {
        "id": order["id"],
        "total_paise": order["total_paise"],
        "status": order["status"],
    }
