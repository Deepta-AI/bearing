from datetime import datetime, timezone

from inventory.store import WAREHOUSES, Movement, Store


class NotFound(Exception):
    pass


class InventoryService:
    def __init__(self, store: Store):
        self.store = store

    def search_skus(self, query: str, limit: int = 50, offset: int = 0) -> list[dict]:
        q = query.lower()
        hits = [
            s
            for s in self.store.skus.values()
            if q in s.sku.lower() or q in s.title.lower()
        ]
        return [self._sku_dict(s) for s in hits[offset : offset + limit]]

    def get_sku(self, sku: str) -> dict:
        s = self.store.skus.get(sku)
        if s is None:
            raise NotFound(sku)
        return self._sku_dict(s)

    def get_stock(self, sku: str) -> dict[str, int]:
        if sku not in self.store.skus:
            raise NotFound(sku)
        return {wh: self.store.stock.get((sku, wh), 0) for wh in WAREHOUSES}

    def adjust_stock(self, sku: str, warehouse: str, delta: int, reason: str) -> int:
        if sku not in self.store.skus:
            raise NotFound(sku)
        new = self.store.stock.get((sku, warehouse), 0) + delta
        self.store.stock[(sku, warehouse)] = new
        self.store.movements.append(
            Movement(
                sku, warehouse, delta, reason, datetime.now(timezone.utc).isoformat()
            )
        )
        print(f"adjusted {sku}@{warehouse} by {delta} -> {new}")
        return new

    def movements(self, sku: str) -> list[dict]:
        return [dict(m.__dict__) for m in self.store.movements if m.sku == sku]

    def archive_sku(self, sku: str) -> None:
        if sku not in self.store.skus:
            raise NotFound(sku)
        self.store.skus[sku].archived = True

    def delete_sku(self, sku: str) -> None:
        """Removes the SKU, its stock rows and its movement history."""
        if sku not in self.store.skus:
            raise NotFound(sku)
        del self.store.skus[sku]
        self.store.stock = {k: v for k, v in self.store.stock.items() if k[0] != sku}
        self.store.movements = [m for m in self.store.movements if m.sku != sku]

    @staticmethod
    def _sku_dict(s) -> dict:
        return {
            "sku": s.sku,
            "title": s.title,
            "category": s.category,
            "archived": s.archived,
            "supplier": dict(s.supplier.__dict__),
        }
