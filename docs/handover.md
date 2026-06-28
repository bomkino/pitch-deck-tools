# Pitch Deck Tools Handover

Last updated: 2026-06-28

GitHub repo: `https://github.com/bomkino/pitch-deck-tools`

Current public baseline checked for this handover: `main` at `f9a73a9` before these handover docs were added.

## What We Are Building

Pitch Deck Tools is a small local toolkit for making pitch deck work less chaotic. The tools are meant to run on a normal Mac or Linux machine, keep private project assets local, and help first-time collaborators get useful results without becoming developers first.

There are three apps:

1. Asset Browser: turns messy media folders into a searchable local index.
2. Font Previewer: helps compare fonts and type direction for decks.
3. Deck Prototyper: turns deck copy and media into rough slide frames.

The project is intentionally GitHub-first and beginner-friendly. Public code and docs live in the repo. Private media, client decks, local exports, downloaded assets, and paid fonts stay out of Git.

## Current State

The repo has been cleaned into a clear three-tool structure under `tools/`.

The root README and `docs/getting-started.md` now explain basic Mac and Linux setup. The repo also ignores common private files, including prototyper media, exports, local manifests, asset indexes, and font files.

Deck Prototyper is the most active app right now. It is currently marked as `v0.8.0` and has its own `CHANGELOG.md` and `NEXT_FIXES.md`.

Font Previewer is the next intended focus. It works as a direct HTML/local-server tool, but it needs a proper product pass: clearer importing, richer comparisons, saved type boards, and a better workflow for deck typography decisions.

## App Notes

### Asset Browser

Folder: `tools/asset-browser`

Use it when a project has lots of images, videos, fonts, references, downloads, and visual research. It builds a local browser index and can generate thumbnails when helpers are installed.

Reached:

- Mac and Linux launch scripts exist.
- Local generated data is ignored by Git.
- README explains Pillow and ffmpeg helpers.
- Tags and local indexes are treated as local working files.

Next:

- Make setup more guided inside the app.
- Improve first-run empty states.
- Make Linux thumbnail support easier to understand.
- Add better export/import of tags when a team intentionally wants to share metadata.

### Font Previewer

Folder: `tools/font-previewer`

Use it when choosing or comparing fonts for a pitch deck. This is the next priority.

Reached:

- `typeboards.html` works as a quick font drop/comparison surface.
- `figma-font-test-exporter.html` exists for Figma-oriented experiments.
- Local server script works on Mac/Linux.

Next:

- Make font loading more obvious and forgiving.
- Add preset text for pitch decks: loglines, title slides, finance slides, team bios, quotes, and captions.
- Add saved comparison sets.
- Add exportable type boards.
- Add better font metadata display.
- Make the UI feel more like a calm design tool and less like a one-off test page.

### Deck Prototyper

Folder: `tools/deck-prototyper`

Use it to move from script/copy to rough slide frames. It is the largest and most fragile app, but it has improved a lot.

Reached:

- Versioned as `v0.8.0`.
- Has Script, Curation, Assembly, and Export flow.
- Has reset/backups.
- Defaults closer to one-image-per-slide behavior.
- Has local text/manifest workflow.
- Has slide add/delete/reorder improvements.
- Has assembly controls for media fitting/alignment and visual edge checking.
- Has Linux startup support.

Next:

- Keep stabilizing Assembly, especially transitions between one and two media slots.
- Improve GIF handling with a static-frame picker while preserving GIF labels.
- Make script sync conflict handling clearer.
- Add more visual QA and export preflight checks.
- Keep reducing layout jumpiness between tabs.

## Working Locations

Normal GitHub repo clone:

```text
pitch-deck-tools/
```

Local-only working files stay inside tool folders, for example:

```text
tools/deck-prototyper/_media/
tools/deck-prototyper/deck-copy.txt
tools/deck-prototyper/manifest.json
tools/deck-prototyper/Export/
tools/asset-browser/_index/
```

The offline handover folder created for Kay on this machine is:

```text
OFFLINE_HANDOVER/
```

That folder is intentionally ignored by Git.

## How To Continue In A New Codex Chat

Start by asking Codex to read these files:

```text
README.md
docs/handover.md
docs/todo.md
docs/offline-workflow.md
tools/font-previewer/README.md
```

Then make the next pass on Font Previewer first.

The next chat should preserve the existing simple app structure. Do not turn this into a heavy framework unless there is a strong reason. The current audience includes first-time GitHub users, so every new workflow should stay explainable.

## Release Habit

For each useful batch:

1. Update the relevant README or doc.
2. Update app version/changelog if behavior changed.
3. Test on the local app.
4. Commit to a `codex/...` branch.
5. Push to GitHub.
6. Open and merge a pull request into `main`.
7. Pull or refresh the offline handover folder.

