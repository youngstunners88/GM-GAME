#!/usr/bin/env python3
"""Localhost bridge between the browser pane and the repo (skill gm-game-nft-flow-generation).

The browser pane cannot use native file dialogs, so a page script does the hand-over instead:
  * POST /save?name=<file>   body = image bytes  -> design/nft/lil-blunt-collection/raw/<file>   (page -> repo)
  * GET  /ref/<file>                              -> design/nft/lil-blunt-collection/references/<file>   (repo -> page)
  * GET  /out/<file>                              -> design/nft/lil-blunt-collection/outputs/**/<file>   (repo -> page, for Drive)
Safety: binds 127.0.0.1 only; CORS limited to the Google origins below; saves only PNG/JPEG/WebP (magic bytes), <= 24 MB,
names must match [A-Za-z0-9_.-]+ ; never executes anything; stop it when the batch is done.

    python3 tools/nft/flow_receiver.py [--port 8765]
"""
import argparse
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "design", "nft", "lil-blunt-collection")
ROOT = os.path.normpath(ROOT)
ALLOWED_ORIGINS = {"https://flow.google.com", "https://drive.google.com", "https://labs.google"}
NAME_RE = re.compile(r"^[A-Za-z0-9_.-]{1,120}$")
MAX_BYTES = 24 * 1024 * 1024


def sniff(b):
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        return "png"
    if b[:3] == b"\xff\xd8\xff":
        return "jpg"
    if b[:4] == b"RIFF" and b[8:12] == b"WEBP":
        return "webp"
    return ""


class H(BaseHTTPRequestHandler):
    def _cors(self):
        o = self.headers.get("Origin", "")
        if o in ALLOWED_ORIGINS:
            self.send_header("Access-Control-Allow-Origin", o)
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.send_header("Access-Control-Allow-Private-Network", "true")
            self.send_header("Vary", "Origin")

    def _reply(self, code, body=b"", ctype="text/plain"):
        self.send_response(code)
        self._cors()
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self._reply(204)

    def do_POST(self):
        u = urlparse(self.path)
        if u.path != "/save":
            return self._reply(404, b"no")
        name = (parse_qs(u.query).get("name") or [""])[0]
        if not NAME_RE.match(name):
            return self._reply(400, b"bad name")
        n = int(self.headers.get("Content-Length", "0"))
        if n <= 0 or n > MAX_BYTES:
            return self._reply(413, b"bad size")
        body = self.rfile.read(n)
        kind = sniff(body)
        if not kind:
            return self._reply(415, b"not png/jpeg/webp")
        os.makedirs(os.path.join(ROOT, "raw"), exist_ok=True)
        stem = name.rsplit(".", 1)[0]
        path = os.path.join(ROOT, "raw", f"{stem}.{kind}")
        with open(path, "wb") as f:
            f.write(body)
        print(f"saved {path} ({len(body)} B, {kind})", flush=True)
        self._reply(200, f"{stem}.{kind} {len(body)}".encode())

    def do_GET(self):
        p = urlparse(self.path).path
        for prefix, sub in (("/ref/", "references"), ("/out/", "outputs")):
            if p.startswith(prefix):
                name = p[len(prefix):]
                if not NAME_RE.match(name):
                    return self._reply(400, b"bad name")
                hits = []
                for dp, _, fs in os.walk(os.path.join(ROOT, sub)):
                    if name in fs:
                        hits.append(os.path.join(dp, name))
                if not hits:
                    return self._reply(404, b"missing")
                with open(hits[0], "rb") as f:
                    data = f.read()
                kind = sniff(data)
                ctype = {"png": "image/png", "jpg": "image/jpeg", "webp": "image/webp"}.get(kind, "application/octet-stream")
                return self._reply(200, data, ctype)
        self._reply(200, b"lil-blunt nft receiver ok")

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8765)
    a = ap.parse_args()
    print(f"receiver on 127.0.0.1:{a.port}, root {ROOT}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", a.port), H).serve_forever()
