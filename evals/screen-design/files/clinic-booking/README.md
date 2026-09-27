# Clinic Booking app

Patients book a visit at one of our clinics from their phone. Expo (React
Native) app, phone only; iOS and Android from one codebase.

## Running

```
pnpm install       # not vendored; needs the network
pnpm start         # Expo dev server
make check         # unit tests for src/lib (node --test, no install needed)
```

## Design mockups

The clickable mockups the client reviews live in `docs/design/screens/booking/`
(open any `.html` file in a browser; the bar at the top switches state).

- `screens.json` holds each screen's states and copy; `template.html` is the
  shared page. `make screens` rebuilds every `.html` from them.
- Colours live only in `docs/design/tokens.css`, which every mockup links.
  Mockups never declare a colour of their own.
- Client feedback arrives as a notes file in `docs/design/feedback/`.

## Clinic hours

Clinics are closed on Sundays and on the public holidays in
`src/lib/slots.js`; on those days the slots endpoint returns an empty list.
A weekday can also be fully booked.
