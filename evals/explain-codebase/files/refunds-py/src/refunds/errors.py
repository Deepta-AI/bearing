class RefundError(Exception):
    status = 400


class NotFound(RefundError):
    status = 404


class OverRefund(RefundError):
    status = 422
