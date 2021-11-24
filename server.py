from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path


def start_httpd(directory: Path, port: int = 8000):
    print(f"serving from {directory}...")
    handler = partial(SimpleHTTPRequestHandler, directory=directory)
    httpd = HTTPServer(('localhost', port), handler)
    httpd.serve_forever()

start_httpd("./bin/")