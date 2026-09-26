"""JSON HTTP API: POST /postings, GET /balances/<account>, GET /healthz."""

import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

from ledger.accounts import MemoryLedger, PostgresLedger, Posting, UnbalancedPosting
from ledger.money import format_amount, parse_amount


def make_ledger():
    dsn = os.environ.get("DATABASE_URL")
    return PostgresLedger(dsn) if dsn else MemoryLedger()


class Handler(BaseHTTPRequestHandler):
    ledger = None

    def _send(self, status: int, body: dict) -> None:
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        if self.path == "/healthz":
            self._send(200, {"status": "ok"})
        elif self.path.startswith("/balances/"):
            account = self.path.removeprefix("/balances/")
            try:
                self._send(
                    200,
                    {"account": account, "balance": format_amount(self.ledger.balance(account))},
                )
            except KeyError:
                self._send(404, {"error": "unknown account"})
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path != "/postings":
            self._send(404, {"error": "not found"})
            return
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        posting = Posting(
            body["reference"],
            [(line["account"], parse_amount(line["amount"])) for line in body["lines"]],
        )
        try:
            created = self.ledger.post(posting)
        except (UnbalancedPosting, KeyError, ValueError) as err:
            self._send(422, {"error": str(err)})
            return
        self._send(201 if created else 200, {"reference": posting.reference, "created": created})


def main() -> None:
    Handler.ledger = make_ledger()
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()


if __name__ == "__main__":
    main()
