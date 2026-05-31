#!/usr/bin/env python3
"""
consolidate_fonts.py — Collect every font in the project into one folder.

For each subfolder of Fonts/, pick the best available format:
    1. Variable TTF   (best for Figma)
    2. OTF
    3. Static TTF

Copy every weight/style in the chosen format to _index/fonts-to-install/.
Skip WOFF/WOFF2 (web-only).

Never modifies, renames, or deletes anything in the source Fonts/ folder.
The output folder (fonts-to-install/) is overwritten on each run — by design,
so it always exactly mirrors what's currently in the project.
"""

import os, sys, shutil, re
from pathlib import Path

SCRIPT_DIR  = Path(__file__).resolve().parent
INDEX_DIR   = SCRIPT_DIR.parent
PROJECT_DIR = INDEX_DIR.parent
FONTS_DIR   = PROJECT_DIR / "Fonts"
OUT_DIR     = INDEX_DIR / "fonts-to-install"
REPORT      = INDEX_DIR / "fonts-report.txt"

SKIP_NAMES = {".DS_Store", "Icon\r", "Icon", ".localized"}

def is_variable_ttf(path):
    """A variable TTF has an 'fvar' table. Its 4-byte tag appears in the
    table directory near the start of the file — first 16 KB is plenty."""
    try:
        with open(path, "rb") as f:
            head = f.read(16384)
        return b"fvar" in head
    except Exception:
        return False

def _path_preference(path):
    """Lower score = more preferred. Penalize 'web' folders, reward 'desktop'/'opentype'."""
    p = str(path).lower()
    score = 0
    if "/web" in p or "web-" in p:           score += 10   # web variants last
    if "desktop" in p or "opentype" in p:    score -= 1    # desktop variants first
    return score

def _dedupe_by_name(files):
    """When multiple files share the same name, keep the most-preferred path."""
    by_name = {}
    for f in sorted(files, key=_path_preference):
        by_name.setdefault(f.name, f)
    return list(by_name.values())

def collect_family_files(family_dir):
    """Return {'variable_ttf': [...], 'otf': [...], 'static_ttf': [...]}."""
    buckets = {"variable_ttf": [], "otf": [], "static_ttf": []}
    for f in family_dir.rglob("*"):
        if not f.is_file(): continue
        if f.name in SKIP_NAMES or f.name.startswith("."): continue
        ext = f.suffix.lower()
        if ext == ".ttf":
            if is_variable_ttf(f):
                buckets["variable_ttf"].append(f)
            else:
                buckets["static_ttf"].append(f)
        elif ext == ".otf":
            buckets["otf"].append(f)
    return {k: _dedupe_by_name(v) for k, v in buckets.items()}

def main():
    if not FONTS_DIR.exists():
        sys.exit(f"No Fonts/ folder found at {FONTS_DIR}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    report_lines = [
        "Font consolidation report",
        "=" * 60,
        f"Source:  {FONTS_DIR}",
        f"Output:  {OUT_DIR}",
        "",
        "Priority: variable TTF > OTF > static TTF",
        "WOFF / WOFF2 are skipped (web-only formats).",
        "",
        "─" * 60,
    ]

    chosen_count = 0
    skipped = []
    expected_names = set()   # tracks what should be in OUT_DIR after this run

    for family_dir in sorted(FONTS_DIR.iterdir()):
        if not family_dir.is_dir(): continue
        if family_dir.name in SKIP_NAMES or family_dir.name.startswith("."): continue

        buckets = collect_family_files(family_dir)
        # Pick the highest-priority non-empty tier
        tier = next((t for t in ("variable_ttf", "otf", "static_ttf") if buckets[t]),
                    None)

        family_label = clean_family_name(family_dir.name)
        if tier is None:
            skipped.append(family_label)
            report_lines.append(f"\n{family_label}")
            report_lines.append("  ⚠  no TTF or OTF found")
            continue

        report_lines.append(f"\n{family_label}")
        report_lines.append(f"  → chose: {tier.replace('_', ' ')}")
        report_lines.append(f"  available: " + ", ".join(
            f"{k.replace('_',' ')} ({len(v)})" for k, v in buckets.items() if v
        ))

        for f in buckets[tier]:
            dest = OUT_DIR / f.name
            # If name collision *from a different family*, prefix with folder name
            if dest.name in expected_names:
                dest = OUT_DIR / f"{family_dir.name}__{f.name}"
            shutil.copy2(f, dest)
            expected_names.add(dest.name)
            chosen_count += 1
            report_lines.append(f"     · {dest.name}")

    # Clean up stale font files from previous runs (only ttf/otf, only orphans)
    cleanup_failures = []
    for f in OUT_DIR.iterdir():
        if not f.is_file(): continue
        if f.suffix.lower() not in (".ttf", ".otf"): continue
        if f.name in expected_names: continue
        try:
            f.unlink()
            report_lines.append(f"  removed stale: {f.name}")
        except OSError as e:
            cleanup_failures.append(f.name)
    if cleanup_failures:
        report_lines.append("")
        report_lines.append(f"⚠  Couldn't remove {len(cleanup_failures)} stale file(s) "
                            f"(likely Google Drive lock): {', '.join(cleanup_failures[:5])}"
                            + ("…" if len(cleanup_failures) > 5 else ""))

    report_lines += [
        "",
        "─" * 60,
        f"Copied {chosen_count} font files across "
        f"{sum(1 for d in FONTS_DIR.iterdir() if d.is_dir()) - len(skipped)} families.",
    ]
    if skipped:
        report_lines.append(f"Skipped {len(skipped)} (no usable format): "
                            + ", ".join(skipped))
    report_lines += [
        "",
        "To install: open " + str(OUT_DIR),
        "→ Cmd+A → drag into Font Book.",
    ]

    REPORT.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

    print(f"\n✓ Copied {chosen_count} font files → {OUT_DIR}")
    print(f"✓ Report: {REPORT}")
    print(f"\nTo install: open '{OUT_DIR}' → Cmd+A → drag into Font Book.\n")

def clean_family_name(raw):
    s = re.sub(r'-\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}-utc$', '', raw)
    s = s.replace('-', ' ').replace('_', ' ').strip()
    return ' '.join(w if w.isupper() else w.capitalize() for w in s.split())

if __name__ == "__main__":
    main()
