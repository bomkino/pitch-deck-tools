# Pitch Deck Tools

Local, open-source tools by pitch.dog for people who want to make better pitch decks.

This repo is beginner-friendly on purpose. You do not need to become a developer before the tools become useful. Start with [`docs/getting-started.md`](docs/getting-started.md).

For project continuity, read:

- [`docs/handover.md`](docs/handover.md)
- [`docs/todo.md`](docs/todo.md)
- [`docs/offline-workflow.md`](docs/offline-workflow.md)
- [`docs/new-chat-brief.md`](docs/new-chat-brief.md)

## What is inside

| Tool | Folder | Platform | What it does |
| --- | --- | --- | --- |
| Asset Browser | `tools/asset-browser` | Mac / Linux browser tool | Turns a messy local asset folder into a searchable visual index. |
| Font Previewer | `tools/font-previewer` | **macOS 13+ native app** | Reviews font files, collections, axes, features, coverage, pairings, and exportable deck specimens without installing or uploading them. |
| Deck Prototyper | `tools/deck-prototyper` | Mac / Linux browser tool | Turns deck copy and local media into rough slide frames. |

## Who this helps

- filmmakers and producers building pitch materials;
- founders preparing an investor deck;
- students and first-time creators learning how decks work;
- small teams organising visual research;
- deck makers who need faster local tools for messy early-stage work.

## Get the project

### GitHub Desktop

1. Install GitHub Desktop.
2. Open this repository on GitHub.
3. Click `Code` → `Open with GitHub Desktop`.
4. Choose a local folder and clone.

### Terminal

```bash
git clone https://github.com/bomkino/pitch-deck-tools.git
cd pitch-deck-tools
```

Update later with GitHub Desktop’s **Pull origin**, or:

```bash
git pull
```

## Font Previewer — native Mac app

Font Previewer is now Mac-only by design. It uses CoreText directly, opens files and folders without installing fonts, saves readable `.pitchfontstudy` documents, watches source files, and exports PNG, PDF, JSON, and Markdown through one renderer.

Requirements:

- macOS 13 Ventura or newer;
- Apple command-line developer tools for source builds.

Build, test, package, verify, and install:

```text
tools/font-previewer/build-font-previewer-app.command
```

Build without touching `/Applications`:

```bash
tools/font-previewer/build-font-previewer-app.command --no-install
```

Read [`tools/font-previewer/README.md`](tools/font-previewer/README.md) before working on it. The older HTML pages remain as legacy reference, not the current product.

## Deck Prototyper

Current prototyper version: `v0.8.0`.

### Mac

Double-click:

```text
tools/deck-prototyper/start-prototyper.command
```

Or:

```bash
cd tools/deck-prototyper
python3 app.py
```

### Linux

```bash
cd tools/deck-prototyper
./start-prototyper.sh
```

If the browser does not open, visit the local URL printed in Terminal. Use another port with:

```bash
PORT=8010 python3 app.py
```

## Asset Browser

### Mac

Double-click:

```text
tools/asset-browser/open-index.command
```

### Linux or Terminal

```bash
cd tools/asset-browser
./open-index.sh
```

For richer thumbnails:

```bash
python3 -m pip install Pillow
```

Install `ffmpeg` for video thumbnails.

## Private files stay private

Do not commit client work, paid fonts, studies, exports, downloaded asset packs, or personal project media.

The repository ignores common local material, including:

- font files and `.pitchfontstudy` documents;
- Font Previewer build output;
- Deck Prototyper media, manifests, backups, and exports;
- Asset Browser indexes, thumbnails, and local tags;
- common private media formats.

More detail: [`docs/assets-and-privacy.md`](docs/assets-and-privacy.md).

## Troubleshooting

### A command file is blocked

Right-click it, choose **Open**, then confirm. For source scripts, you can also run:

```bash
chmod +x tools/font-previewer/build-font-previewer-app.command
chmod +x tools/font-previewer/run-font-previewer.command
chmod +x tools/deck-prototyper/start-prototyper.sh
chmod +x tools/asset-browser/open-index.sh
```

### A local browser tool cannot be reached

Keep the Terminal process running. Press `Ctrl+C` there when finished.

### The wrong version is showing

Stop the running tool, pull the repository, rebuild, and reopen it.

## Project status

This is active, production-adjacent open-source work. Rough edges should be documented, tested, and removed—not romanticised.

See [`docs/roadmap.md`](docs/roadmap.md) and the per-tool documentation for current boundaries.
