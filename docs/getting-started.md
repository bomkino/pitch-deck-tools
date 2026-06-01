# Getting Started For First-Timers

This guide is for people who are new to GitHub, Terminal, or local web tools.

## The Big Idea

These tools run on your own computer. They do not upload your deck, images, fonts, or client files to pitch.dog.

Most tools start a small local server. That means:

1. You run a command in Terminal.
2. Terminal prints a local URL.
3. You open that URL in a browser.
4. You keep Terminal open while you work.
5. You press `Ctrl+C` in Terminal when you are done.

## Install The Basics

You need:

- Python 3
- Git or GitHub Desktop
- A modern browser

Check Python:

```bash
python3 --version
```

Check Git:

```bash
git --version
```

If either command says it cannot find the program, install it first.

## Download The Project

### Easiest: GitHub Desktop

1. Install GitHub Desktop.
2. Open the repo page in your browser.
3. Click `Code`.
4. Click `Open with GitHub Desktop`.
5. Click `Clone`.

### Terminal

```bash
git clone https://github.com/bomkino/pitch-deck-tools.git
cd pitch-deck-tools
```

## Update The Project Later

If you used GitHub Desktop, click `Fetch origin`, then `Pull origin`.

If you use Terminal:

```bash
cd pitch-deck-tools
git pull
```

## Start A Tool

Deck Prototyper:

```bash
cd tools/deck-prototyper
python3 app.py
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

## Mac Notes

Mac users can also double-click `.command` files, such as:

```text
tools/deck-prototyper/start-prototyper.command
tools/asset-browser/open-index.command
```

If macOS blocks a file because it came from the internet, right-click it, choose `Open`, then confirm.

## Linux Notes

Use the `.sh` files or the `python3` commands.

If Linux says `Permission denied`, run:

```bash
chmod +x tools/deck-prototyper/start-prototyper.sh
chmod +x tools/asset-browser/open-index.sh
chmod +x tools/font-previewer/start-font-previewer.sh
```

For better image thumbnail support:

```bash
python3 -m pip install Pillow
```

For video thumbnails:

```bash
sudo apt install ffmpeg
```

## Stop A Tool

Go back to the Terminal window running the tool and press:

```text
Ctrl+C
```

## What Not To Upload

Do not upload private project files, paid fonts, client media, exports, or downloaded asset packs.

The repo already ignores many local files, but it is still good to check GitHub Desktop or `git status` before committing.
