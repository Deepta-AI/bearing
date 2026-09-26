# Churn model, first cut.
# Builds one row per user per month, trains a logistic regression and prints the test AUC.
# Run: python3 train.py

import csv
import datetime as dt
import math
import random

random.seed(1)

# ---- load
users = {r["user_id"]: r for r in csv.DictReader(open("data/users.csv"))}
events = list(csv.DictReader(open("data/events.csv")))
for e in events:
    e["date"] = dt.date.fromisoformat(e["date"])

by_user = {}
for e in events:
    by_user.setdefault(e["user_id"], []).append(e)

EXPORT_DATE = dt.date(2026, 6, 30)  # users.csv is the profile export from this date

# ---- features, one row per user per month
SNAPSHOTS = [dt.date(2026, m, 1) for m in (2, 3, 4, 5, 6)]
rows = []
for uid, u in users.items():
    evs = by_user.get(uid, [])
    sessions = [e for e in evs if e["event"] == "session"]
    total_sessions = len(sessions)
    days_active = len({e["date"] for e in sessions})
    tickets = sum(1 for e in evs if e["event"] == "support_ticket")
    last_seen = dt.date.fromisoformat(u["last_seen"]) if u["last_seen"] else EXPORT_DATE
    for snap in SNAPSHOTS:
        if dt.date.fromisoformat(u["signup_date"]) >= snap:
            continue
        last_30 = sum(1 for e in sessions if snap - dt.timedelta(days=30) <= e["date"] < snap)
        if last_30 == 0:
            continue  # only users active in the last 30 days are worth a retention call
        days_since_seen = (snap - last_seen).days  # days since the user was last seen
        churned = not any(snap <= e["date"] < snap + dt.timedelta(days=30) for e in sessions)
        rows.append(
            {
                "user_id": uid,
                "snapshot": snap.isoformat(),
                "x": [
                    math.log1p(total_sessions),
                    math.log1p(days_active),
                    tickets,
                    days_since_seen / 30,
                    math.log1p(last_30),
                    1.0 if u["plan"] == "quarterly" else 0.0,
                ],
                "y": 1 if churned else 0,
            }
        )

# ---- split
random.shuffle(rows)
cut = int(len(rows) * 0.8)
train, test = rows[:cut], rows[cut:]

# ---- logistic regression, plain gradient descent
k = len(train[0]["x"])
means = [sum(r["x"][j] for r in train) / len(train) for j in range(k)]
sds = [
    (sum((r["x"][j] - means[j]) ** 2 for r in train) / len(train)) ** 0.5 or 1.0
    for j in range(k)
]


def z(x):
    return [(x[j] - means[j]) / sds[j] for j in range(k)]


w, b = [0.0] * k, 0.0
for _ in range(300):
    gw, gb = [0.0] * k, 0.0
    for r in train:
        xs = z(r["x"])
        p = 1 / (1 + math.exp(-(sum(wj * xj for wj, xj in zip(w, xs)) + b)))
        for j in range(k):
            gw[j] += (p - r["y"]) * xs[j]
        gb += p - r["y"]
    w = [wj - 0.5 * g / len(train) for wj, g in zip(w, gw)]
    b -= 0.5 * gb / len(train)


def score(r):
    xs = z(r["x"])
    return sum(wj * xj for wj, xj in zip(w, xs)) + b


def auc(rs):
    pos = [score(r) for r in rs if r["y"] == 1]
    neg = [score(r) for r in rs if r["y"] == 0]
    wins = sum((p > n) + 0.5 * (p == n) for p in pos for n in neg)
    return wins / (len(pos) * len(neg))


print(f"rows: {len(rows)} (train {len(train)}, test {len(test)})")
print(f"churn rate: {sum(r['y'] for r in rows) / len(rows):.1%}")
print(f"test AUC: {auc(test):.3f}")
