"""Local dev server for Paperfjord: like `python -m http.server`, but tells the browser not to cache,
so a reload always picks up edited modules. Usage: python serve.py [port]

It listens on both loopback addresses (two listeners), IPv6 (::1) and IPv4 (127.0.0.1). Browsers try ::1 first for
"localhost"; bound to 127.0.0.1 alone, some of the many module requests would stall until they timed out,
and the game would hang at random on load."""
import http.server
import socket
import sys


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, format, *args):  # quiet: one line per module request floods the log
        pass


class V6Server(http.server.ThreadingHTTPServer):
    address_family = socket.AF_INET6
    daemon_threads = True
    request_queue_size = 128


class V4Server(http.server.ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 128


if __name__ == '__main__':
    import threading
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5173
    servers = [V4Server(('127.0.0.1', port), NoCacheHandler)]
    try:
        servers.append(V6Server(('::1', port), NoCacheHandler))  # loopback only, both families
    except OSError:
        pass
    print(f'Serving Paperfjord at http://localhost:{port}')
    for srv in servers[1:]:
        threading.Thread(target=srv.serve_forever, daemon=True).start()
    servers[0].serve_forever()
