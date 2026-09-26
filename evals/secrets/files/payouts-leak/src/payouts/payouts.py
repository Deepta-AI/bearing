"""Pay a seller out, once per payout id."""


def pay(gateway, store, payout_id, account, amount_paise):
    if amount_paise <= 0:
        raise ValueError("payout amount must be positive")
    if payout_id in store:
        return store[payout_id]
    result = gateway.create_payout(payout_id, account, amount_paise)
    store[payout_id] = result["status"]
    return result["status"]
