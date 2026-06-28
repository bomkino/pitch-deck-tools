# Offline Workflow

Last updated: 2026-06-28

This guide is for working without internet after the project has already been downloaded.

## Before Going Offline

Do this while you still have internet:

1. Open the GitHub repo.
2. Download or clone the latest project.
3. Make sure the tools open once on your computer.
4. Copy any private project assets you need into local ignored folders.
5. Keep this repo folder somewhere easy to find.

If you use Terminal:

```bash
git clone https://github.com/bomkino/pitch-deck-tools.git
cd pitch-deck-tools
```

If you already have the repo:

```bash
cd pitch-deck-tools
git pull
```

## Where Private Work Goes

Use local ignored folders:

```text
tools/deck-prototyper/_media/
tools/deck-prototyper/deck-copy.txt
tools/deck-prototyper/manifest.json
tools/deck-prototyper/Export/
tools/asset-browser/_index/
OFFLINE_HANDOVER/
```

Do not put private client files into public docs or sample folders unless you truly intend to publish them.

## Running While Offline

Deck Prototyper:

```bash
cd tools/deck-prototyper
python3 app.py
```

Then open:

```text
http://localhost:8000/index.html
```

Asset Browser:

```bash
cd tools/asset-browser
./open-index.sh
```

Font Previewer:

```bash
cd tools/font-previewer
./start-font-previewer.sh
```

Then open:

```text
http://localhost:8020/typeboards.html
```

## Saving Work Offline

The apps save local files on your machine. GitHub does not need to be online for the tools to run.

If you are editing code or docs while offline, you can still save a Git checkpoint:

```bash
git status
git add README.md docs tools
git commit -m "Describe what changed"
```

When internet returns:

```bash
git pull
git push
```

If Git says there is a conflict, stop and ask Codex or a teammate before guessing.

## Offline Handover Folder

Kay's local offline handover folder is:

```text
OFFLINE_HANDOVER/
```

It should contain a latest copy of the repo, a copy of the handover docs, and a next-chat prompt. It is ignored by Git so it can safely contain local notes.

Refresh it after a major GitHub merge.

## Noob-Friendly Rule

When in doubt:

1. Keep private work local.
2. Do not delete unknown files.
3. Do not commit fonts, client media, or exports.
4. Ask for help before resolving Git conflicts.

