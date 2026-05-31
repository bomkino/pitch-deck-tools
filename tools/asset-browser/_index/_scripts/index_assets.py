#!/usr/bin/env python3
import os, sys, json, hashlib, subprocess, tempfile, time, re, zipfile
from pathlib import Path
import concurrent.futures

SCRIPT_DIR  = Path(__file__).resolve().parent
INDEX_DIR   = SCRIPT_DIR.parent
PROJECT_DIR = INDEX_DIR.parent
THUMBS_DIR  = INDEX_DIR / "thumbs"
HTML_OUT    = INDEX_DIR / "index.html"
TAGS_FILE   = INDEX_DIR / "tags.json"
TEMPLATE    = SCRIPT_DIR / "template.html"

THUMB_SIZE  = 500
MAX_THUMBS  = 64     # 🚀 INCREASED FROM 16 TO 64!
TIMEOUT     = 5      

SKIP_NAMES = {".DS_Store", "Icon\r", "Icon", ".localized", "__MACOSX"}
SKIP_DIRS  = {"_index"}

LOOSE_BUNDLE_EXTS = {
    ".zip", ".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".tif", ".tiff",
    ".psd", ".ai", ".eps", ".pdf", ".mp4", ".mov", ".m4v", ".webm", ".otf", ".ttf"
}

def short_hash(s, n=10):
    return hashlib.md5(s.encode()).hexdigest()[:n]

def print_progress(current, total, text):
    pct = int(current / total * 100) if total else 100
    bar = "█" * (pct // 5) + "░" * (20 - (pct // 5))
    sys.stdout.write("\r" + " " * 80 + "\r")
    sys.stdout.write(f"  [{bar}] {pct:3d}% · {text[:40].ljust(40)}")
    sys.stdout.flush()

def main():
    if not PROJECT_DIR.exists(): sys.exit(f"Project dir not found: {PROJECT_DIR}")
    THUMBS_DIR.mkdir(parents=True, exist_ok=True)

    print(f"\nIndexing  {PROJECT_DIR}\n", flush=True)
    
    tasks = []
    for cat_path in sorted(PROJECT_DIR.iterdir()):
        if not cat_path.is_dir() or cat_path.name in SKIP_DIRS or cat_path.name.startswith((".", "_")): 
            continue
        for entry in sorted(cat_path.iterdir()):
            if entry.name in SKIP_NAMES or entry.name.startswith("."): continue
            if entry.is_dir() or (entry.is_file() and entry.suffix.lower() in LOOSE_BUNDLE_EXTS):
                tasks.append((cat_path.name, entry))

    bundles = []
    total_tasks = len(tasks)
    completed = 0

    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = {executor.submit(scan_bundle, cat, entry): (cat, entry) for cat, entry in tasks}
        for future in concurrent.futures.as_completed(futures):
            cat, entry = futures[future]
            completed += 1
            print_progress(completed, total_tasks, entry.name)
            try:
                b = future.result()
                if b: bundles.append(b)
            except Exception as e:
                pass

    print("\n")
    user_data = _load_user_data()
    write_html(bundles, user_data)
    print(f"\nDone. {len(bundles)} bundles → {HTML_OUT}")

def scan_bundle(category, path):
    rel = path.relative_to(PROJECT_DIR)
    bundle_id = short_hash(str(rel))

    if path.suffix.lower() == ".zip":
        thumbs = _zip_thumbs(path, bundle_id)
    else:
        sources = _pick_preview_sources(path, MAX_THUMBS)
        thumbs = []
        for src in sources:
            rel_source = str(src.relative_to(PROJECT_DIR))
            src_key = short_hash(rel_source, n=8)
            tp = THUMBS_DIR / f"{bundle_id}_{src_key}.jpg"
            try: src_mtime = src.stat().st_mtime
            except FileNotFoundError: continue
            
            if not tp.exists() or tp.stat().st_mtime < src_mtime:
                _make_thumb(src, tp)
            if tp.exists():
                thumbs.append({"url": f"thumbs/{tp.name}", "source": rel_source})

    files = _list_files(path)
    return {
        "id":         bundle_id,
        "category":   category,
        "name":       clean_name(path.stem if path.is_file() else path.name),
        "raw_name":   path.name,
        "rel_path":   str(rel),
        "abs_path":   str(path),
        "thumbs":     thumbs,
        "files":      files,
        "file_count": len(files),
        "types":      sorted({Path(f).suffix.lower().lstrip('.') for f in files if Path(f).suffix})[:10],
        "size_mb":    round(_bundle_size(path) / 1_000_000, 1),
        "added":      _bundle_added_ts(path),
    }

def _pick_preview_sources(bundle, max_n):
    if bundle.is_file():
        if bundle.suffix.lower() in (".otf", ".ttf", ".woff", ".woff2"): return []
        return [bundle]

    candidates = []
    for f in bundle.rglob("*"):
        if not f.is_file() or f.name in SKIP_NAMES or f.name.startswith(".") or "__MACOSX" in f.parts: continue
        if f.suffix.lower() in (".otf", ".ttf", ".woff", ".woff2"): continue
        candidates.append(f)
        
    if not candidates: return []

    def score(f):
        ext = f.suffix.lower()
        type_rank = {".jpg": 0, ".jpeg": 0, ".png": 0, ".webp": 0, ".tif": 1, ".psd": 3, ".pdf": 4, ".ai": 5, ".eps": 5, ".mp4": 6, ".mov": 6}.get(ext, 9)
        name_l = f.name.lower()
        bonus = -3 if "preview" in name_l else 0
        pen = 1 if "/web" in str(f).lower() else 0
        if any(t in name_l for t in ("help", "guide", "readme")): type_rank += 5
        return (type_rank + bonus + pen, f.name.lower())

    candidates.sort(key=score)
    seen_sizes, out = set(), []
    for c in candidates:
        size = c.stat().st_size
        if size in seen_sizes: continue
        seen_sizes.add(size)
        out.append(c)
        if len(out) >= max_n: break
    return out

def _zip_thumbs(zip_path, bundle_id):
    out = []
    try:
        with zipfile.ZipFile(zip_path) as z:
            imgs = [n for n in z.namelist() if n.lower().endswith((".jpg", ".jpeg", ".png", ".webp")) and "__MACOSX" not in n]
            if not imgs: return out
            imgs.sort(key=lambda n: (-1 if "preview" in n.lower() else 0, z.getinfo(n).file_size, n.lower()))
            chosen = imgs[:MAX_THUMBS]

            with tempfile.TemporaryDirectory() as tmp:
                zip_mtime = zip_path.stat().st_mtime
                rel_zip = str(zip_path.relative_to(PROJECT_DIR))
                for entry in chosen:
                    src_key = short_hash(f"{rel_zip}#{entry}", n=8)
                    tp = THUMBS_DIR / f"{bundle_id}_{src_key}.jpg"
                    if tp.exists() and tp.stat().st_mtime >= zip_mtime:
                        out.append({"url": f"thumbs/{tp.name}", "source": rel_zip})
                        continue
                    z.extract(entry, tmp)
                    if _run(["sips", "-Z", str(THUMB_SIZE), "-s", "format", "jpeg", str(Path(tmp) / entry), "--out", str(tp)]):
                        out.append({"url": f"thumbs/{tp.name}", "source": rel_zip})
    except Exception: pass
    return out

def _make_thumb(source, thumb):
    ext = source.suffix.lower()
    try:
        if ext in (".jpg", ".jpeg", ".png", ".gif", ".tiff", ".tif", ".webp", ".heic"):
            return _run(["sips", "-Z", str(THUMB_SIZE), "-s", "format", "jpeg", str(source), "--out", str(thumb)])
        if ext in (".mp4", ".mov", ".m4v", ".webm"):
            return _run(["ffmpeg", "-y", "-i", str(source), "-ss", "00:00:01", "-vframes", "1", "-vf", f"scale={THUMB_SIZE}:-1", str(thumb)])
        with tempfile.TemporaryDirectory() as tmp:
            _run(["qlmanage", "-t", "-s", str(THUMB_SIZE), "-o", tmp, str(source)])
            pngs = [p for p in Path(tmp).iterdir() if p.suffix.lower() == ".png"]
            if pngs: return _run(["sips", "-s", "format", "jpeg", str(pngs[0]), "--out", str(thumb)])
    except Exception: return False
    return False

def _run(cmd):
    try: return subprocess.run(cmd, capture_output=True, timeout=TIMEOUT).returncode == 0
    except Exception: return False

def _list_files(bundle):
    if bundle.is_file():
        if bundle.suffix.lower() == ".zip":
            try:
                with zipfile.ZipFile(bundle) as z:
                    return sorted(n for n in z.namelist() if not n.endswith("/") and "__MACOSX" not in n)
            except Exception: return [bundle.name]
        return [bundle.name]
    out = []
    for f in bundle.rglob("*"):
        if f.is_file() and f.name not in SKIP_NAMES and not f.name.startswith(".") and "__MACOSX" not in f.parts:
            out.append(str(f.relative_to(bundle)))
    return sorted(out)

def _bundle_size(bundle):
    if bundle.is_file(): return bundle.stat().st_size
    return sum(f.stat().st_size for f in bundle.rglob("*") if f.is_file())

def _bundle_added_ts(bundle):
    if bundle.is_file(): return int(bundle.stat().st_mtime)
    mts = [f.stat().st_mtime for f in bundle.rglob("*") if f.is_file()]
    return int(min(mts)) if mts else int(bundle.stat().st_mtime)

def _load_user_data():
    try: return json.loads(TAGS_FILE.read_text(encoding="utf-8")) if TAGS_FILE.exists() else {}
    except Exception: return {}

def clean_name(raw):
    s = re.sub(r'\.zip$', '', raw, flags=re.I)
    s = re.sub(r'\.(jpg|jpeg|png|psd|ai|eps|pdf|mp4|mov)$', '', s, flags=re.I)
    s = re.sub(r'-\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}-utc$', '', s)
    return ' '.join(w if w.isupper() else w.capitalize() for w in s.replace('-', ' ').replace('_', ' ').strip().split())

def write_html(bundles, user_data):
    proj_name = PROJECT_DIR.parent.name + " · assets" if PROJECT_DIR.name.lower() == "assets" else PROJECT_DIR.name
    html = TEMPLATE.read_text(encoding="utf-8")
    html = html.replace("__DATA__", json.dumps(bundles, ensure_ascii=False))
    html = html.replace("__USER_DATA__", json.dumps(user_data, ensure_ascii=False))
    html = html.replace("__PROJECT__", proj_name)
    html = html.replace("__PROJECT_KEY__", short_hash(str(PROJECT_DIR)))
    html = html.replace("__GENERATED__", time.strftime("%a %d %b %Y, %H:%M"))
    html = html.replace("__COUNT__", str(len(bundles)))
    HTML_OUT.write_text(html, encoding="utf-8")

if __name__ == "__main__": main()
