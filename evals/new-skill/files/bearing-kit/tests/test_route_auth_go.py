import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "plugins", "bearing-backend", "bin", "route-auth-go.py")


def run(files):
    with tempfile.TemporaryDirectory() as repo:
        for name, body in files.items():
            path = os.path.join(repo, name)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as f:
                f.write(body)
        return subprocess.run(
            [sys.executable, SCRIPT, repo], capture_output=True, text=True
        )


class RouteAuthGo(unittest.TestCase):
    def test_wrapped_route_passes(self):
        r = run({"main.go": 'mux.HandleFunc("GET /orders", requireAuth(listOrders))\n'})
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("1 routes, 0 without auth", r.stdout)

    def test_bare_route_fails(self):
        r = run({"main.go": 'mux.HandleFunc("POST /orders", createOrder)\n'})
        self.assertEqual(r.returncode, 1)
        self.assertIn("POST /orders has no auth", r.stdout)

    def test_public_route_listed(self):
        r = run({
            "main.go": 'mux.HandleFunc("GET /healthz", health)\n',
            ".bearing/public-routes.txt": "GET /healthz\n",
        })
        self.assertEqual(r.returncode, 0, r.stdout)


if __name__ == "__main__":
    unittest.main()
