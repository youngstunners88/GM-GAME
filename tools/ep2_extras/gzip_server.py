# Serves a directory like itch's CDN: when the client accepts gzip, .pck/.wasm/.js are sent gzip-encoded with
# Content-Length = the COMPRESSED size (what makes Godot 4.3's web HTTPRequest fail with "err != 0 && err != 1").
import gzip, http.server, os, sys
root, port = sys.argv[1], int(sys.argv[2])
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k): super().__init__(*a, directory=root, **k)
    def do_GET(self):
        path = self.translate_path(self.path.split('?')[0])
        if os.path.isfile(path) and path.endswith(('.pck', '.wasm', '.js')) and 'gzip' in self.headers.get('Accept-Encoding', ''):
            data = gzip.compress(open(path, 'rb').read(), 6)
            self.send_response(200)
            self.send_header('Content-Type', 'application/octet-stream' if not path.endswith('.js') else 'application/javascript')
            self.send_header('Content-Encoding', 'gzip')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        super().do_GET()
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(('127.0.0.1', port), H).serve_forever()
