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

## Start

On a Mac, double-click:

```text
start-prototyper.command
```

Or run:

```bash
python3 app.py
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

The app falls back to `deck-copy.example.txt` when `deck-copy.txt` does not exist.

## Current Limitation

The export workflow currently lives inside the browser app. The `export-slides.command` helper is not a true headless exporter yet.

