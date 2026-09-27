# Transactional email

The backend sends order confirmation, dispatch and delivery emails through
Postbird, our email service provider. Templates live in the backend repo
(`emails/templates/`); the app team owns only the links inside them.

## Links and click tracking

Every link in every template is written as the plain URL, for example
`https://pantry.example.com/orders/<id>`. Click tracking is switched on
for the whole account (marketing reports click-through per template), so
Postbird rewrites each link at send time to
`https://t.pantrymail.example.net/c/<opaque-token>` and answers a tap
with a 302 redirect to the original URL.

## Sender

`orders@pantry.example.com`, with SPF and DKIM set up on
`pantrymail.example.net`.
