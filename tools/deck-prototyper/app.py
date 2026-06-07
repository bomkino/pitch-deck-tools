#!/usr/bin/env python3
import base64
import http.server
import json
import os
import re
import shutil
import socketserver
import string
import subprocess
import sys
import webbrowser
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PROJECT_DIR = Path(__file__).resolve().parent
MEDIA_DIR = PROJECT_DIR / "_media"
THUMBS_DIR = MEDIA_DIR / ".thumbs"
BACKUPS_DIR = PROJECT_DIR / "_backups"
MANIFEST_FILE = PROJECT_DIR / "manifest.json"
COPY_FILE = PROJECT_DIR / "deck-copy.txt"
EXAMPLE_COPY_FILE = PROJECT_DIR / "deck-copy.example.txt"
PORT = int(os.environ.get("PORT", "8000"))
OPEN_BROWSER = os.environ.get("PROTOTYPER_OPEN_BROWSER", "1") != "0"
APP_VERSION = "0.6.0"

RESET_COPY = """=== 1 ===
HEAD: Untitled Slide
SUB:
BODY:
"""

THUMBS_DIR.mkdir(parents=True, exist_ok=True)
IS_MACOS = sys.platform == "darwin"


def parse_deck_copy():
    source_file = COPY_FILE if COPY_FILE.exists() else EXAMPLE_COPY_FILE
    if not source_file.exists():
        return []
    content = source_file.read_text(encoding="utf-8")
    slides = []
    blocks = re.split(r"^===\s*(\d+)\s*===$", content, flags=re.MULTILINE)
    for i in range(1, len(blocks), 2):
        slide_num = blocks[i]
        slide_content = blocks[i + 1].strip()
        head_match = re.search(r"^HEAD:[ \t]*(.*)$", slide_content, flags=re.MULTILINE)
        sub_match = re.search(r"^SUB:[ \t]*(.*)$", slide_content, flags=re.MULTILINE)
        body_match = re.search(
            r"^BODY:[ \t]*(.*)$", slide_content, flags=re.MULTILINE | re.DOTALL
        )
        slides.append(
            {
                "slide": slide_num,
                "head": head_match.group(1).strip() if head_match else "",
                "sub": sub_match.group(1).strip() if sub_match else "",
                "body": body_match.group(1).strip() if body_match else "",
            }
        )
    return slides


def scan_media():
    media = []
    if MEDIA_DIR.exists():
        valid_exts = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif"}
        for root, _, files in os.walk(MEDIA_DIR):
            if ".thumbs" in root:
                continue
            for file in files:
                path = Path(root) / file
                if path.suffix.lower() in valid_exts and not file.startswith("."):
                    media.append(
                        {
                            "filename": file,
                            "path": path.relative_to(PROJECT_DIR).as_posix(),
                            "type": path.suffix.lower().lstrip("."),
                        }
                    )
    return media


def deck_copy_status():
    source_file = COPY_FILE if COPY_FILE.exists() else EXAMPLE_COPY_FILE
    if not source_file.exists():
        return {"source": None, "mtime": None}
    return {
        "source": source_file.name,
        "mtime": source_file.stat().st_mtime,
    }


def write_deck_copy(slides):
    out_text = ""
    for s in slides:
        out_text += f"=== {s['slide']} ===\nHEAD: {s.get('head', '')}\nSUB: {s.get('sub', '')}\nBODY:\n{s.get('body', '')}\n\n"
    COPY_FILE.write_text(out_text.strip() + "\n", encoding="utf-8")


def backup_project(label):
    from datetime import datetime

    stamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    safe_label = "".join(c if c.isalnum() else "-" for c in label).strip("-")
    backup_dir = BACKUPS_DIR / f"{stamp}-{safe_label}"
    backup_dir.mkdir(parents=True, exist_ok=True)

    for path in [
        MANIFEST_FILE,
        COPY_FILE,
        PROJECT_DIR / "prototyper-log.txt",
        PROJECT_DIR / "app.py",
        PROJECT_DIR / "app.js",
        PROJECT_DIR / "index.html",
        PROJECT_DIR / "styles.css",
    ]:
        if path.exists():
            shutil.copy2(path, backup_dir / path.name)

    return backup_dir


def generate_thumb(original_path, thumb_path):
    if IS_MACOS:
        result = subprocess.run(
            [
                "sips",
                "-Z",
                "800",
                "-s",
                "format",
                "jpeg",
                str(original_path),
                "--out",
                str(thumb_path),
            ],
            capture_output=True,
        )
        if result.returncode == 0 and thumb_path.exists():
            return True
    try:
        from PIL import Image

        with Image.open(original_path) as img:
            img.thumbnail((800, 800))
            if img.mode in ("RGBA", "LA", "P"):
                img = img.convert("RGB")
            img.save(thumb_path, "JPEG", quality=85)
        return True
    except ImportError:
        return False
    except Exception:
        return False


def resolve_export_dir(project_name, version):
    safe_proj = "".join(c if c.isalnum() else "-" for c in project_name).strip("-")
    safe_vers = "".join(c if c.isalnum() or c == "." else "-" for c in version).strip(
        "-"
    )
    base_name = f"{safe_proj}_{safe_vers}" if safe_proj else safe_vers

    export_root = PROJECT_DIR / "Export"
    target_dir = export_root / base_name

    if not target_dir.exists():
        target_dir.mkdir(parents=True)
        return target_dir

    for char in string.ascii_lowercase:
        test_dir = export_root / f"{base_name}_{char}"
        if not test_dir.exists():
            test_dir.mkdir(parents=True)
            return test_dir

    return target_dir


class PrototyperHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(PROJECT_DIR), **kwargs)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/data":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            data = {
                "appVersion": APP_VERSION,
                "slides": parse_deck_copy(),
                "media": scan_media(),
                "deckCopy": deck_copy_status(),
                "manifest": json.loads(MANIFEST_FILE.read_text(encoding="utf-8"))
                if MANIFEST_FILE.exists()
                else {},
            }
            self.wfile.write(json.dumps(data).encode("utf-8"))
            return

        if parsed.path == "/api/thumb":
            rel_path = parse_qs(parsed.query).get("file", [""])[0]
            if rel_path:
                original = PROJECT_DIR / rel_path
                if original.exists():
                    safe_name = (
                        str(original.relative_to(MEDIA_DIR)).replace("/", "__") + ".jpg"
                    )
                    thumb_path = THUMBS_DIR / safe_name
                    if (
                        not thumb_path.exists()
                        or thumb_path.stat().st_mtime < original.stat().st_mtime
                    ):
                        generate_thumb(original, thumb_path)
                    if thumb_path.exists():
                        self.path = "/" + thumb_path.relative_to(PROJECT_DIR).as_posix()
                    else:
                        self.path = "/" + rel_path
            super().do_GET()
            return
        super().do_GET()

    def do_POST(self):
        if self.path == "/api/save":
            content_length = int(self.headers["Content-Length"])
            MANIFEST_FILE.write_text(
                self.rfile.read(content_length).decode("utf-8"), encoding="utf-8"
            )
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode("utf-8"))
            return

        if self.path == "/api/sync":
            content_length = int(self.headers["Content-Length"])
            payload = json.loads(self.rfile.read(content_length).decode("utf-8"))
            write_deck_copy(payload)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode("utf-8"))
            return

        if self.path == "/api/reset-project":
            backup_dir = backup_project("reset-project")
            MANIFEST_FILE.write_text(json.dumps({}, indent=2), encoding="utf-8")
            COPY_FILE.write_text(RESET_COPY, encoding="utf-8")
            data = {
                "status": "ok",
                "backup": backup_dir.relative_to(PROJECT_DIR).as_posix(),
                "slides": parse_deck_copy(),
                "manifest": {},
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode("utf-8"))
            return

        if self.path == "/api/export-media":
            content_length = int(self.headers["Content-Length"])
            payload = json.loads(self.rfile.read(content_length).decode("utf-8"))

            project_name = payload.get("project", "Untitled")
            version = payload.get("version", "v1.0")
            export_dir = resolve_export_dir(project_name, version)

            mains_dir = export_dir / "Media_Mains"
            backups_dir = export_dir / "Media_Backups"
            mains_dir.mkdir(exist_ok=True)
            backups_dir.mkdir(exist_ok=True)

            manifest = payload.get("manifest", {})
            all_media = payload.get("media", [])
            slots = manifest.get("slideSlots", {})
            media_lookup = {m["filename"]: m["path"] for m in all_media}

            for slide_num, data in slots.items():
                pad_slide = str(slide_num).zfill(2)
                mains = data.get("mains", [])
                backups = data.get("backups", [])

                for idx, filename in enumerate(mains):
                    if filename in media_lookup:
                        src_path = PROJECT_DIR / media_lookup[filename]
                        if src_path.exists():
                            suffix = (
                                f"-{string.ascii_uppercase[idx]}"
                                if len(mains) > 1
                                else ""
                            )
                            safe_name = f"Slide-{pad_slide}-Main{suffix}-{filename}"
                            shutil.copy2(src_path, mains_dir / safe_name)

                for filename in backups:
                    if filename in media_lookup:
                        src_path = PROJECT_DIR / media_lookup[filename]
                        if src_path.exists():
                            safe_name = f"Slide-{pad_slide}-Backup-{filename}"
                            shutil.copy2(src_path, backups_dir / safe_name)

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(
                json.dumps({"status": "ok", "folder": export_dir.name}).encode("utf-8")
            )
            return

        if self.path == "/api/export-visuals":
            content_length = int(self.headers["Content-Length"])
            payload = json.loads(self.rfile.read(content_length).decode("utf-8"))

            folder_name = payload.get("folder")
            if not folder_name:
                self.send_response(400)
                self.end_headers()
                return

            export_dir = PROJECT_DIR / "Export" / folder_name
            visuals_dir = export_dir / "Visual_Frames"
            visuals_dir.mkdir(parents=True, exist_ok=True)

            images_data = payload.get("images", [])
            saved_paths = []

            for img in images_data:
                slide_num = str(img.get("slide")).zfill(2)
                data_url = img.get("data", "")
                if "," in data_url:
                    header, encoded = data_url.split(",", 1)
                    file_data = base64.b64decode(encoded)
                    file_path = visuals_dir / f"Slide_{slide_num}.jpg"
                    with open(file_path, "wb") as f:
                        f.write(file_data)
                    saved_paths.append(file_path)

            try:
                from PIL import Image

                if saved_paths:
                    pdf_path = export_dir / f"{folder_name}_Visuals.pdf"
                    pil_images = [Image.open(p).convert("RGB") for p in saved_paths]
                    pil_images[0].save(
                        pdf_path,
                        save_all=True,
                        append_images=pil_images[1:],
                        resolution=100.0,
                    )
                    print(f"\n[SUCCESS] Compiled Visual PDF: {pdf_path}")
            except ImportError:
                print("\n" + "=" * 60)
                print("[ERROR] PDF GENERATION FAILED")
                print(
                    "The frames were saved as JPGs, but Python could not stitch them."
                )
                print(
                    "You must install Pillow to generate PDFs. Run this in your terminal:"
                )
                print("pip3 install Pillow")
                print("=" * 60 + "\n")
            except Exception as e:
                print(f"\n[ERROR] Something went wrong compiling the PDF: {e}")

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode("utf-8"))
            return

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()


def main():
    if "--export" in sys.argv:
        print("Headless export is not implemented yet.")
        print("Start the app and use the Export tab in the browser.")
        sys.exit(0)
    if not MANIFEST_FILE.exists():
        MANIFEST_FILE.write_text(json.dumps({}), encoding="utf-8")
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), PrototyperHandler) as httpd:
        print(f"\n[SYSTEM ONLINE] Serving UI at http://localhost:{PORT}/index.html")
        if OPEN_BROWSER:
            try:
                webbrowser.open(f"http://localhost:{PORT}/index.html")
            except Exception:
                print("[INFO] Browser did not open automatically.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[SYSTEM OFFLINE]")


if __name__ == "__main__":
    main()
