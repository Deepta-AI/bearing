# Event design rules

## What is an event

A thing that happened that the business wants to count or follow: a
decision, a completion, a failure the user saw. Not a render, not a
network call, not a state change nobody would chart.

## The taxonomy for an application

1. Lifecycle: `app_opened`, `app_backgrounded`, `session_started`,
   `screen_viewed`, `consent_updated`.
2. Identity: `signed_up`, `logged_in`, `logged_out`, `account_deleted`.
3. Per user journey (from the user flows document): one event per step
   that a user completes or abandons, and one per error the user sees.
   The journey's funnel is the ordered list of these events.
4. Business outcomes: the events revenue or retention are computed from
   (`order_placed`, `subscription_renewed`, `invoice_paid`), with the
   amounts as properties in minor units and a currency.
5. Feature adoption: one `feature_used` per feature with `feature` as a
   property, or a specific event when the feature has its own funnel.

## Properties

- Every property has a type, a source (where the value comes from in
  code), and, for strings, either an enumeration or a maximum length.
- Amounts are integers in minor units plus `currency`.
- Ids reference domain entities (`invoice_id`), never row numbers.
- Free text from users is never a property.
- Booleans are named as states (`is_first_order`), not questions.

## Trigger discipline

- One trigger point per event, at the moment the thing became true (the
  server response for server-side outcomes, the user action for
  client-side intents). Name the layer in the sheet.
- Server-side outcomes are emitted from the backend when the client could
  lie or lose connectivity (payments, signups).
- Client intents (`checkout_started`) are emitted from the client.

## Testing

- The catalogue test: the generated event catalogue equals the sheet.
- The emission test: for each journey's happy path, a test asserts the
  ordered list of events emitted (web: Playwright with a mocked analytics
  endpoint; RN: jest with the analytics module mocked; backend: unit test
  on the service with a fake emitter).

## Auditing

Emitted but not designed: the event is deleted or designed, never left.
Designed but never emitted: the sheet row is removed or the code added.
Shape drift between platforms: one shape wins, both are fixed in one MR.
