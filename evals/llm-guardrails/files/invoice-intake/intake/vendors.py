"""Vendor master. Synthetic data: GSTINs, PANs and accounts are made up."""

from dataclasses import dataclass


@dataclass
class Vendor:
    id: str
    name: str
    gstin: str
    billing_email: str
    bank_account: str
    ifsc: str


class VendorDirectory:
    def __init__(self):
        self._by_gstin = {
            v.gstin: v
            for v in (
                Vendor("V-17", "Kaveri Office Supplies", "29ABCDE1234F1Z5", "billing@kaveri-office.example",
                       "001234567890", "EXMP0001234"),
                Vendor("V-22", "Nilgiri Facility Services", "33PQRST6789K1Z2", "accounts@nilgiri-fs.example",
                       "009876543210", "EXMP0005678"),
            )
        }

    def by_gstin(self, gstin: str) -> Vendor | None:
        return self._by_gstin.get(gstin)

    def update_bank(self, gstin: str, bank_account: str, ifsc: str) -> None:
        v = self._by_gstin[gstin]
        v.bank_account, v.ifsc = bank_account, ifsc
