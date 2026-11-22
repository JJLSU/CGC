"""Receives baked textures from the running web game and writes them into godot/assets/baked/.

    python godot/tools/bake_server.py        (listens on 127.0.0.1:5199)

The browser POSTs a PNG body to http://127.0.0.1:5199/save?path=<relative path>.png (CORS open, loopback only).
Paths are kept inside assets/baked (no '..', no absolute paths)."""
import http.server
import os
import sys
import urllib.parse

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'baked'))


class Handler(http.server.BaseHTTPRequestHandler):
    def cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def do_OPTIONS(self):
        self.send_response(204); self.cors(); self.end_headers()

    def do_POST(self):
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        rel = (q.get('path') or [''])[0].replace('\\', '/')
        dest = os.path.abspath(os.path.join(ROOT, rel))
        if not rel or '..' in rel.split('/') or not dest.startswith(ROOT + os.sep) or not rel.endswith(('.png', '.json', '.glb', '.wav')):
            self.send_response(400); self.cors(); self.end_headers(); return
        n = int(self.headers.get('Content-Length', '0'))
        data = self.rfile.read(n)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, 'wb') as f:
            f.write(data)
        self.send_response(200); self.cors(); self.end_headers(); self.wfile.write(b'ok')

    def log_message(self, fmt, *args):
        pass


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5199
    http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler).serve_forever()
