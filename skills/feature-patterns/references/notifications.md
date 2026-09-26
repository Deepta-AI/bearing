# Pattern: notifications

One notification is an event, a recipient, a channel and a template.
Preferences decide the channel, batching decides the timing, the
delivery log proves what left, and every message can be turned off.

Markers: `sendgrid|ses|postmark|resend|twilio|fcm|apns|expo-notifications|onesignal|unsubscribe|notification_preferences|digest`
Decision keys (ADR grep): `notification`, `email provider`, `push`, `sms`

## Decision questions

1. Channels at launch: email, push, SMS, in-app? Recommend email plus
   in-app first; push when the mobile app exists; SMS only for OTP and
   time-critical alerts (cost and consent).
2. Providers: one per channel through an adapter interface so the
   provider can change without touching senders.
3. Which events notify, and which are transactional (always sent:
   receipt, password reset) against optional (preference-controlled)?
   The list is written before any template.
4. Preferences granularity: per event type per channel (recommend), or
   per channel only? Plus quiet hours and a global mute for optional.
5. Batching: which events digest (comments, mentions) and at what
   window (hourly, daily at the user's local 09:00)? Transactional never
   batches.
6. Localisation: templates per locale from the string catalog
   (`i18n`), with the user's locale on the recipient.

## Data model

```
notification_types(key, channel_defaults jsonb, transactional bool, digestible bool, template_key)
notification_preferences(user_id, type_key, channel, enabled, updated_at)  -- absent row = default
notifications(id, user_id, tenant_id, type_key, payload jsonb, created_at, read_at)      -- the in-app feed
deliveries(id, notification_id, channel, provider, provider_ref, status[queued|sent|delivered|bounced|failed|suppressed],
           attempts, last_error, scheduled_for, sent_at, updated_at)
suppressions(user_id or address, channel, reason[unsubscribed|bounced|complaint], created_at)
devices(user_id, platform, token, last_seen_at, disabled_at)
```

Templates: `templates/<type_key>/<channel>.<locale>.<ext>` in the repo,
rendered with the payload; subject and body reviewed as code.

## Flow

1. Domain event fires; the notifier resolves the type, the recipients and
   the channels from preferences and suppressions.
2. One `notifications` row (in-app), one `deliveries` row per channel,
   `scheduled_for` now or the next digest window.
3. Worker sends due deliveries through the adapter with retries (3, backoff);
   provider webhooks (delivered, bounced, complaint) update status and
   write suppressions.
4. Unsubscribe: a signed link per email (`List-Unsubscribe` header and a
   one-click endpoint) writes a preference or a suppression without login.
5. Digest job renders one message from the pending digestible deliveries
   per user per window and marks them sent.

## Failure modes

| Fault | Handling |
| --- | --- |
| provider outage | deliveries stay `queued`; retries with backoff; alert on queue age over 10 minutes; transactional may fail over to a second provider |
| duplicate sends on retry | `deliveries.id` as the provider idempotency key; a retry after a timeout checks the provider first |
| bounce loop | a hard bounce writes a suppression; sends to a suppressed address are `suppressed`, not attempted |
| stale device tokens | `disabled_at` on the provider's "unregistered" response; never delete, for audit |
| notification storm (one event, 10k recipients) | fan-out in the worker in batches with a per-tenant rate; never in the request |
| wrong locale or timezone | recipient carries both; a missing one falls back to the tenant default and is logged |
| PII in the payload | payload holds ids and short strings; the template fetches what it renders; logs never print the body |
| unsubscribe link forged | signed with a per-user secret and an expiry; a test forges one |

## Tests to write

- a transactional event sends even when every optional preference is off
- an optional event with the channel disabled creates no delivery
- a suppressed address produces `suppressed`, never a provider call
- a provider timeout followed by success creates one send (idempotency key)
- a bounce webhook writes the suppression and the next send is suppressed
- two digestible events in one window produce one digest message
- the unsubscribe link disables the type and channel without a session; a forged link is 400
- the in-app feed marks read and the unread count is correct across two devices

## Per-stack pointers

- Go: adapter interface per channel; official SDKs (SES, Postmark, Twilio, FCM, APNs via `sideshow/apns2`); templates with `html/template`.
- Python: the same adapters; `jinja2` templates with autoescape; `httpx` with timeouts on every provider call.
- React: in-app feed via the realtime pattern; preference screen generated from `notification_types`.
- React Native: `expo-notifications` for tokens and foreground handling; register the token on login, disable on logout.
- Android and iOS: FCM and APNs tokens refreshed on app start; notification channels (Android) and categories (iOS) mirror the type list.
