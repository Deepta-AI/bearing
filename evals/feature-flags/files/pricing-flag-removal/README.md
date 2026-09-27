# storefront

Server-rendered storefront pages and invoice lines for the subscription
product. Standard library only.

    make check    # pytest

Flags are `FLAG_<NAME>` environment variables read by `app/flags.py`; the
register is docs/operations/flags.md. Each region deploys with its own env
file under deploy/. The server calls the page functions in `app/web.py`
with the signed-in account.

Files under static/ are served by the CDN at /static/<name> with
`Cache-Control: public, max-age=604800` (seven days).

Pricing page behaviour and support notes: docs/pricing.md.
