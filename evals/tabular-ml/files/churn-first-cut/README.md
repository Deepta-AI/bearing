# fitloop churn

Fitloop is a subscription home-workout app (monthly or quarterly plans). The
retention team wants a list every Monday of the active subscribers most
likely to stop using the app in the next 30 days, so they can call the top
50. "Stopped" means no workout session in the 30 days after the list is made.

## Data (export taken on 2026-06-30)

- `data/users.csv`: one row per subscriber: `user_id`, `signup_date`, `plan`,
  `city_tier`, and `last_seen` (date of the latest session, as of the export).
- `data/events.csv`: `user_id`, `date`, `event` (`session`, `payment`,
  `support_ticket`), 1 January to 30 June 2026.

## First cut

`train.py` is a first cut written in a notebook and pasted into a file. It
reports a test AUC of 0.98. Run it with `python3 train.py` (standard library
only).

No scikit-learn or pandas on the analytics box; standard library Python only.
