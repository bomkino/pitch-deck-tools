# Pitch Deck Tools

Mac-first, local tools for people who want to make better pitch decks.

This is one open-source project with three early tools:

- **Asset Browser**: scan a folder of visual references, fonts, images, downloads, and design assets into a searchable local browser.
- **Font Previewer**: drop in font files and generate quick type boards for deck typography exploration.
- **Deck Prototyper**: turn rough copy, reference images, and layout choices into quick visual pitch-deck frames.

I am using this project to learn coding and GitHub in public, on a real project. The bigger goal is to help pitch deck makers who cannot afford a professional deck team make stronger decks on their own. It should also help professional teams move faster, so the project can be useful on both sides.

This is early and messy in places. That is part of the point.

## Tools

| Tool | Folder | What it does |
| --- | --- | --- |
| Asset Browser | `tools/asset-browser` | Creates a local visual index of project assets, with thumbnails, tags, filters, and Finder reveal/open actions. |
| Font Previewer | `tools/font-previewer` | Creates large visual boards from dropped font files so you can compare type quickly. |
| Deck Prototyper | `tools/deck-prototyper` | Local browser app for script, media curation, slide assembly, and visual export. |

## Mac-first

This project is being built for macOS first. Some tools currently rely on Mac utilities like `open`, `sips`, `qlmanage`, and LaunchAgents.

Cross-platform support can come later.

## Privacy and Assets

The public repo is for the tools, not for private client work, paid fonts, actor images, deck exports, or downloaded asset packs.

Those files are intentionally ignored by Git. See [docs/assets-and-privacy.md](docs/assets-and-privacy.md).

## Getting Started

Clone the repo, then open one of the tool folders:

```bash
cd tools/deck-prototyper
python3 app.py
```

Or on a Mac, double-click:

```text
tools/deck-prototyper/start-prototyper.command
```

Each tool folder has its own README.

## Project Status

This is an active learning project and a real production-adjacent toolkit. Expect rough edges, simple code, and frequent changes.

See [docs/roadmap.md](docs/roadmap.md) for the direction.

