from wsgiref.simple_server import make_server

from stock.app import make_app

application = make_app()

if __name__ == "__main__":
    with make_server("", 8000, application) as server:
        print("stock-api on :8000")
        server.serve_forever()
