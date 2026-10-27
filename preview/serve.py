#!/usr/bin/env python3
"""Preview host for the corner assistant. Not Logos Basecamp."""

import json
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = {
    "/": ROOT / "preview" / "public" / "index.html",
    "/index.html": ROOT / "preview" / "public" / "index.html",
    "/lambda.svg": ROOT / "assistant" / "lambda.svg",
}
PORT = 47291
LOCK = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        file = FILES.get(path)
        if file is None or not file.is_file():
            self.send_error(404)
            return
        body = file.read_bytes()
        kind = "image/svg+xml" if file.suffix == ".svg" else "text/html; charset=utf-8"
        self._bytes(200, kind, body)

    def do_POST(self):
        path = self.path.split("?", 1)[0]
        length = int(self.headers.get("Content-Length") or 0)
        if length:
            self.rfile.read(length)
        if path != "/api/run-node":
            self.send_error(404)
            return
        if not LOCK.acquire(blocking=False):
            self._json(409, {"ok": False, "summary": "A run is already in progress.", "detail": ""})
            return
        try:
            proc = subprocess.run(
                ["python3", str(ROOT / "preview" / "run_node.py")],
                capture_output=True,
                text=True,
                timeout=420,
            )
        except subprocess.TimeoutExpired:
            self._json(504, {"ok": False, "summary": "The node run timed out.", "detail": ""})
            return
        finally:
            LOCK.release()
        try:
            payload = json.loads(proc.stdout)
        except json.JSONDecodeError:
            payload = {
                "ok": False,
                "summary": "The node did not start.",
                "detail": (proc.stderr or proc.stdout or "run_node.py returned no JSON")[-1600:],
            }
        self._json(200 if payload.get("ok") else 500, payload)

    def _json(self, status, payload):
        self._bytes(status, "application/json", json.dumps(payload).encode())

    def _bytes(self, status, kind, body):
        self.send_response(status)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"http://127.0.0.1:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
