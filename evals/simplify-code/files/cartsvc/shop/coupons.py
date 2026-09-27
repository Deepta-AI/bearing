"""Coupon discounts.

This module provides coupon validation and discount calculation.
"""

import json
import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path

logger = logging.getLogger(__name__)

# Path to the coupons file.
COUPONS_FILE = Path(__file__).resolve().parent.parent / "data" / "coupons.json"


class CouponError(Exception):
    """Raised when a coupon cannot be applied."""


@dataclass(frozen=True)
class Coupon:
    """A coupon."""

    code: str
    percent: Decimal
    min_subtotal: Decimal


def _safe_upper(value):
    """Safely convert a value to upper case."""
    # handle None
    if value is None:
        return ""
    # strip and upper-case the value
    return value.strip().upper()


def _round_money(amount):
    """Round an amount to 2 decimal places."""
    return amount.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def load_coupons(path=COUPONS_FILE):
    """Load the coupons from the JSON file."""
    # open the file and parse it
    with open(path, encoding="utf-8") as f:
        return json.load(f)


class CouponValidator(ABC):
    """Base class for coupon validators."""

    @abstractmethod
    def validate(self, code, subtotal):
        """Validate a coupon code against a subtotal and return the Coupon."""


class DefaultCouponValidator(CouponValidator):
    """The default coupon validator."""

    def __init__(self, coupons=None):
        # load the coupons if none were given
        self.coupons = coupons if coupons is not None else load_coupons()

    def validate(self, code, subtotal):
        # normalise the code
        code = _safe_upper(code)
        # look up the coupon
        raw = self.coupons.get(code)
        if raw is None:
            raise CouponError(f"unknown coupon {code}")
        coupon = Coupon(code, Decimal(raw["percent"]), Decimal(raw["min_subtotal"]))
        # check the minimum subtotal
        if subtotal < coupon.min_subtotal:
            raise CouponError(f"{code} needs a subtotal of at least {coupon.min_subtotal}")
        # return the coupon
        return coupon


def get_validator(coupons=None):
    """Factory that returns the coupon validator."""
    return DefaultCouponValidator(coupons)


def discount_for(code, subtotal, strict=False, coupons=None):
    """Return the discount a coupon gives on subtotal.

    Args:
        code: the coupon code.
        subtotal: the cart subtotal.
        strict: whether to use strict validation.
        coupons: the coupons to use (defaults to the coupons file).

    Returns:
        The discount.
    """
    try:
        validator = get_validator(coupons)
        coupon = validator.validate(code, subtotal)
        # calculate the discount
        return _round_money(subtotal * coupon.percent / 100)
    except CouponError as e:
        # re-raise coupon errors
        raise e
    except Exception:
        logger.exception("coupon %s could not be applied", code)
        return Decimal("0.00")
