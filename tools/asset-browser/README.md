# Asset Browser

The Asset Browser turns a folder full of project assets into a searchable local web page.

It is useful for deck work because pitch decks often require lots of visual hunting: references, poster ideas, textures, fonts, stills, screenshots, and downloaded design packs.

## What It Does

- Scans asset folders.
- Generates thumbnails when possible.
- Builds a local browser index.
- Lets you filter and sort assets.
- Lets you tag assets in the browser.
- Opens files or their containing folder from the browser.
- Consolidates installable fonts into one folder.

## Start On Mac

Double-click:

```text
open-index.command
```

Or use Terminal:

```bash
./open-index.sh
```

## Start On Linux

```bash
cd tools/asset-browser
./open-index.sh
```

If Linux says `Permission denied`:

```bash
chmod +x open-index.sh index-assets.sh consolidate-fonts.sh
```

## Rebuild The Index

```bash
./index-assets.sh
```

## Optional Thumbnail Helpers

For image thumbnails on Linux:

```bash
python3 -m pip install Pillow
```

For video thumbnails:

```bash
sudo apt install ffmpeg
```

Mac users usually get image thumbnails through built-in macOS tools. Linux users get common image thumbnails through Pillow and video thumbnails through ffmpeg.

## Notes

Generated thumbnails, tag exports, local indexes, and installed-font output are ignored by Git. They are useful locally, but they should not be published by default.
