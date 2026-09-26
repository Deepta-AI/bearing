# order-alerts

Hourly order-volume alert for a grocery delivery app operating in four
cities. A cron job runs `python3 -m alerts.rules` at five past every hour on
the previous hour's order count and pages the on-call engineer for every
line it prints.

## Data

- `data/orders_hourly.csv`: orders per hour, 24 August to 15 November 2026
  (12 weeks, IST).
- `data/incidents.csv`: real incidents from the postmortem log in that
  period, with start and end hour.
- `data/calendar.csv`: holidays and festivals the business plans for.

## Tests

    make test

Standard library Python only on the alerting host.
