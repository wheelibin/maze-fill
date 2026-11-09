#!/usr/bin/env python3
"""Static server for build/web with the COOP/COEP headers Godot's web export needs."""
import http.server

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

if __name__ == "__main__":
    http.server.test(HandlerClass=Handler, port=8060, bind="127.0.0.1")
