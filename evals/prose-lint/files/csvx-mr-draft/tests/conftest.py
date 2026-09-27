import csv

import pytest


@pytest.fixture
def reviews(tmp_path):
    src = tmp_path / "reviews.csv"
    rows = [
        {"id": "1", "product": "kettle", "rating": "poor"},
        {"id": "2", "product": "kettle", "rating": "good"},
        {"id": "3", "product": "toaster", "rating": "excellent"},
        {"id": "4", "product": "toaster", "rating": "fair"},
    ]
    with open(src, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["id", "product", "rating"])
        w.writeheader()
        w.writerows(rows)
    return src


def read(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))
