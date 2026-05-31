# Asset Browser

The Asset Browser turns a folder full of project assets into a searchable local web page.

It is useful for deck work because pitch decks often require lots of visual hunting: references, poster ideas, textures, fonts, stills, screenshots, and downloaded design packs.

## What It Does

- Scans asset folders.
- Generates thumbnails.
- Builds a local browser index.
- Lets you filter and sort assets.
- Lets you tag assets in the browser.
- Opens or reveals files in Finder.
- Consolidates installable fonts into one folder.

## Mac Usage

Double-click:

```text
open-index.command
```

That starts a tiny local web server and opens the asset index in your browser.

## Notes

Generated thumbnails, tag exports, local indexes, and installed-font output are ignored by Git. They are useful locally, but they should not be published by default.

