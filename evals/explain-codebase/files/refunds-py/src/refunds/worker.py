import time

from refunds import config, log
from refunds.gateway import Razorpay
from refunds.store import Store

logger = log.get("refunds.worker")


def run_once(store: Store, gateway: Razorpay) -> int:
    sent = 0
    for refund_id, order_id, amount_paise in store.approved():
        try:
            gateway.refund(order_id, amount_paise)
        except OSError as e:
            logger.warning("refund %s failed: %s", refund_id, e)
            continue
        store.set_status(refund_id, "sent")
        sent += 1
    return sent


def main():
    cfg = config.load()
    store, gateway = Store(cfg.db_path), Razorpay(cfg.razorpay_base_url)
    while True:
        logger.info("sent %d refunds", run_once(store, gateway))
        time.sleep(cfg.worker_poll_seconds)


if __name__ == "__main__":
    main()
