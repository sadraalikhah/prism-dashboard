#!/usr/bin/env python3
"""Serve the interactive preview and save its browser recording locally."""
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

recording = Path('/tmp/prism-clock-preview.webm')


class Preview(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(Path(__file__).resolve().parent), **kwargs)

    def do_POST(self):
        size = int(self.headers.get('Content-Length', '0'))
        if self.path != '/clock-recording.webm' or not 0 < size <= 50_000_000:
            self.send_error(400)
            return
        recording.write_bytes(self.rfile.read(size))
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        if self.path == '/clock-recording.webm' and recording.exists():
            self.send_response(200)
            self.send_header('Content-Type', 'video/webm')
            self.send_header('Content-Length', str(recording.stat().st_size))
            self.end_headers()
            self.wfile.write(recording.read_bytes())
        else:
            super().do_GET()


if __name__ == '__main__':
    HTTPServer(('127.0.0.1', 8767), Preview).serve_forever()
