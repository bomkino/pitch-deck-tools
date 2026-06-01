#!/usr/bin/env python3
"""
server.py — Tiny local web server for the asset index.
"""

import http.server
import socketserver
import socket
import shutil
import subprocess
import urllib.parse
import os
import sys
import webbrowser
import json
from pathlib import Path

SCRIPT_DIR  = Path(__file__).resolve().parent
INDEX_DIR   = SCRIPT_DIR.parent
PROJECT_DIR = INDEX_DIR.parent
INDEXER     = SCRIPT_DIR / "index_assets.py"

DEFAULT_PORT = int(os.environ.get("PORT", "8765"))
OPEN_BROWSER = os.environ.get("ASSET_BROWSER_OPEN_BROWSER", "1") != "0"
PORT_RANGE = 50

def _open_file(path, reveal=False):
    if sys.platform == "darwin":
        cmd = ["open", "-R", str(path)] if reveal else ["open", str(path)]
        subprocess.Popen(cmd)
        return

    if sys.platform.startswith("linux"):
        opener = shutil.which("xdg-open")
        if not opener:
            raise RuntimeError("xdg-open is not installed")
        target = path.parent if reveal else path
        subprocess.Popen([opener, str(target)])
        return

    if os.name == "nt":
        os.startfile(str(path.parent if reveal else path))  # type: ignore[attr-defined]
        return

    raise RuntimeError(f"Opening files is not supported on {sys.platform}")

def _resolve_path(target):
    target_path = Path(target)
    
    local_rel = PROJECT_DIR / target_path
    if local_rel.exists():
        return local_rel.resolve()
        
    if target_path.is_absolute() and target_path.exists():
        return target_path.resolve()
        
    try:
        parts = target_path.parts
        proj_name = PROJECT_DIR.name
        if proj_name in parts:
            idx = parts.index(proj_name)
            rel_parts = parts[idx+1:]
            recovered = PROJECT_DIR.joinpath(*rel_parts)
            if recovered.exists():
                return recovered.resolve()
    except ValueError:
        pass

    return None

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(INDEX_DIR), **kwargs)

    def log_message(self, fmt, *args):
        if args and len(args) >= 2:
            status = args[1] if len(args) > 1 else ""
            path = args[0] if args else ""
            if "/_" in str(path) and status.startswith("2"):
                print(f"  {self.address_string()} -> {path}", flush=True)
            elif not status.startswith("2"):
                print(f"  {self.address_string()} <- {path} {status}", flush=True)

    def _send_json(self, payload, status=200):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == "/_info":
            return self._send_json({
                "project_dir": str(PROJECT_DIR),
                "project_name": PROJECT_DIR.name,
            })

        if parsed.path == "/_open":
            qs = urllib.parse.parse_qs(parsed.query)
            target = qs.get("path", [""])[0]
            reveal = qs.get("reveal", ["0"])[0] == "1"
            if not target:
                return self._send_json({"ok": False, "error": "missing path"}, 400)

            resolved = _resolve_path(target)
            if resolved is None:
                return self._send_json(
                    {"ok": False, "error": f"not found: {target}"}, 404)
            try:
                _open_file(resolved, reveal=reveal)
                return self._send_json({"ok": True, "resolved": str(resolved)})
            except Exception as e:
                return self._send_json({"ok": False, "error": str(e)}, 500)

        if parsed.path == "/_reindex":
            try:
                result = subprocess.run(
                    [sys.executable, str(INDEXER)],
                    capture_output=True, timeout=600
                )
                return self._send_json({
                    "ok": result.returncode == 0,
                    "stdout": result.stdout.decode("utf-8", errors="replace")[-2000:],
                    "stderr": result.stderr.decode("utf-8", errors="replace")[-2000:],
                })
            except subprocess.TimeoutExpired:
                return self._send_json({"ok": False, "error": "indexer timed out"}, 504)
            except Exception as e:
                return self._send_json({"ok": False, "error": str(e)}, 500)

        if parsed.path in ("", "/"):
            self.path = "/index.html"
        return super().do_GET()

def find_port(start, span):
    for p in range(start, start + span):
        try:
            with socket.socket() as s:
                s.bind(("127.0.0.1", p))
                return p
        except OSError:
            continue
    raise RuntimeError(f"No free port in {start}..{start + span}")

def main():
    if not (INDEX_DIR / "index.html").exists():
        print("No index.html yet. Running the indexer first.", flush=True)
        subprocess.run([sys.executable, str(INDEXER)])

    port = find_port(DEFAULT_PORT, PORT_RANGE)
    url = f"http://localhost:{port}/"

    print("\n" + "=" * 50)
    print("  pitch.dog asset server")
    print(f"  {url}")
    print("=" * 50)
    print(f"\n  Project:  {PROJECT_DIR}")
    print(f"\n  Browser is {'opening' if OPEN_BROWSER else 'available'} at the URL above.")
    print(f"  Keep this Terminal window open while you work.")
    print(f"  Close this window (or Ctrl+C) to stop the server.\n")

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", port), Handler) as httpd:
        if OPEN_BROWSER:
            webbrowser.open(url)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n  Server stopped.\n")

if __name__ == "__main__":
    main()
