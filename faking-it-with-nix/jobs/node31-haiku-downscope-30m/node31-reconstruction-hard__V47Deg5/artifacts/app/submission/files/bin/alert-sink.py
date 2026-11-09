import json
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = "/var/lib/alert-sink/received.jsonl"


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        with open(LOG, "ab") as handle:
            handle.write(json.dumps({"path": self.path, "body": json.loads(body or b"null")}).encode() + b"\n")
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        if self.path != "/received":
            self.send_error(404)
            return
        try:
            lines = open(LOG, "rb").read().splitlines()
        except FileNotFoundError:
            lines = []
        data = json.dumps([json.loads(line) for line in lines]).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", 19190), Handler).serve_forever()
