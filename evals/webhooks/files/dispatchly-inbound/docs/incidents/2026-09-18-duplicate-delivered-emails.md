# 2026-09-18: customers got two "delivered" emails

Reported by support: 37 customers received the delivered email twice,
some three times, between 09:00 and 13:00 IST.

Log excerpt from parcelpost:

    09:14:02.118 POST /webhooks/dispatchly 200 6214ms evt=evt_7Hw1aa
    09:14:08.503 POST /webhooks/dispatchly 200 6109ms evt=evt_7Hw1aa
    09:14:21.990 POST /webhooks/dispatchly 200 5987ms evt=evt_7Hw1aa

The SMTP relay was slow all morning (about 6 s per send). No root cause
written up yet.
