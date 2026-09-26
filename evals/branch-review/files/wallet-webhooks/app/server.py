import logging
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from app import db, settings
from app.webhooks import handler

conn = db.connect(settings.DB_PATH)


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/webhooks/provider":
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length") or 0)
        if length > settings.MAX_BODY_BYTES:
            self.send_response(413)
            self.end_headers()
            return
        body = self.rfile.read(length)
        status = handler.handle(conn, self.headers, body)
        self.send_response(status)
        self.end_headers()


def main():
    logging.basicConfig(level=logging.INFO)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()


if __name__ == "__main__":
    main()
