#!/usr/bin/env python3
import http.server, os, sys
if sys.argv[1:] == ["update"]:
    raise SystemExit(0)
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok\n")
http.server.HTTPServer(("0.0.0.0", int(os.environ.get("PORT", "45876"))), H).serve_forever()
