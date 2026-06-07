# Deck Prototyper

The Deck Prototyper is a local browser app for roughing out pitch deck visuals.

It is designed around four steps:

1. Script
2. Curation
3. Assembly
4. Export

## What It Does

- Reads slide copy from `deck-copy.txt`.
- Scans images from `_media/`.
- Lets you shortlist and assign images to slides.
- Lets you assemble quick deck frames on a canvas.
- Exports visual frames and a PDF from the browser workflow.
- Backs up current project state before using Reset Project.

## Version

Current prototyper app version: `v0.6.0`

Changes are tracked in `CHANGELOG.md`.

The current improvement backlog is tracked in `NEXT_FIXES.md`.

## Start On Mac

Double-click:

```text
start-prototyper.command
```

Or use Terminal:

```bash
python3 app.py
```

## Start On Linux

```bash
cd tools/deck-prototyper
./start-prototyper.sh
```

If Linux says `Permission denied`:

```bash
chmod +x start-prototyper.sh
```

You can also run:

```bash
python3 app.py
```

Optional environment variables:

```bash
PORT=8010 python3 app.py
PROTOTYPER_OPEN_BROWSER=0 python3 app.py
```

Then open:

```text
http://localhost:8000/index.html
```

## Local Working Files

These files are intentionally not committed:

- `_media/`
- `Export/`
- `deck-copy.txt`
- `manifest.json`
- `prototyper-log.txt`
- `_backups/`

The app falls back to `deck-copy.example.txt` when `deck-copy.txt` does not exist.

## Current Limitation

The export workflow currently lives inside the browser app. The `export-slides.command` helper is not a true headless exporter yet.
