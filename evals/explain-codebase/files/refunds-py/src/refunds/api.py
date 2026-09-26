import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from refunds import config, handlers, log
from refunds.service import RefundService
from refunds.store import Store

logger = log.get("refunds.api")


def make_handler(service: RefundService):
    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path != "/refunds":
                self._send(404, {"error": "not found"})
                return
            length = int(self.headers.get("Content-Length", "0"))
            status, body = handlers.create_refund(service, self.rfile.read(length))
            self._send(status, body)

        def _send(self, status: int, body: dict):
            data = json.dumps(body).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    return Handler


def main():
    cfg = config.load()
    service = RefundService(Store(cfg.db_path))
    logger.info("listening on :%d", cfg.port)
    ThreadingHTTPServer(("", cfg.port), make_handler(service)).serve_forever()


if __name__ == "__main__":
    main()
