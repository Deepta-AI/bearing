"""Minimal webhook receiver for local runs."""

from http.server import BaseHTTPRequestHandler, HTTPServer

from payouts import config, webhooks

STORE = {}


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        try:
            webhooks.handle(
                config.load().paygate_secret_key,
                raw,
                self.headers.get("X-PayGate-Signature"),
                STORE,
            )
        except webhooks.BadSignature:
            self.send_response(401)
            self.end_headers()
            return
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    HTTPServer(("", 8080), Handler).serve_forever()
