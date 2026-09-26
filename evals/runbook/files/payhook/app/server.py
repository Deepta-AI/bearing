"""Webhook endpoint: POST /webhooks/provider.

Checks the X-Provider-Signature header, then stores the event as pending.
A bad signature is answered 401 and the event is stored as dead with
last_error 'signature_invalid' so it can be replayed once the secret is fixed
(the provider does not resend after a 401).
"""

import json
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

from app import db, metrics, queue, signature


def store(conn, body, sig, now=None):
    event = json.loads(body)
    queue.enqueue(conn, event["id"], event["type"], json.dumps(event.get("data", {})), now)
    if not signature.verify(body, sig):
        conn.execute(
            "UPDATE events SET status = 'dead', last_error = 'signature_invalid' "
            "WHERE provider_event_id = ?",
            (event["id"],),
        )
        conn.commit()
        metrics.DEAD_LETTERS_TOTAL["count"] += 1
        return 401
    return 202


class Handler(BaseHTTPRequestHandler):
    conn = None

    def do_POST(self):
        if self.path != "/webhooks/provider":
            self.send_response(404)
            self.end_headers()
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        code = store(self.conn, body, self.headers.get("X-Provider-Signature"), time.time())
        self.send_response(code)
        self.end_headers()


def main():
    Handler.conn = db.connect()
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()


if __name__ == "__main__":
    main()
