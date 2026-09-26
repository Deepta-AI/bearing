import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(message)s")


def get(name: str = "refunds") -> logging.Logger:
    return logging.getLogger(name)
