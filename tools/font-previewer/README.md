# Font Previewer

A local, native macOS typography lab for choosing fonts under real pitch-deck conditions.

It does not install fonts, upload them, phone home, or require a browser. Drop in font files or an entire folder; the app reads each face directly through CoreText and keeps the study on your Mac.

## Current status

This native rewrite is under active review on `codex/native-macos-font-lab`. The old HTML experiments remain in this folder as legacy reference, but they are no longer the product direction.

- App version: `0.3.0`
- Minimum system: macOS 13 Ventura
- Build: native Swift + SwiftUI + CoreText
- Signing: ad-hoc for local use
- Notarisation: not yet configured

## What it does

### Import without installing

- Drop files or folders anywhere in the app.
- Recursively scans OTF, TTF, TTC, OTC, dfont, WOFF, and WOFF2 files that CoreText accepts.
- Keeps every collection face distinct.
- De-duplicates by canonical source path plus face index—not by PostScript name.
- Watches source files and reloads changed faces.
- Relinks missing sources without discarding decisions, tags, notes, axes, or features.

### Judge type as deck type

- Pitch-specific presets for titles, loglines, promises, problem statements, quotes, bios, paragraphs, data, captions, legal copy, numerals, glyph stress, and multilingual probes.
- Review, Focus, Compare, Waterfall, Metrics, Glyphs, and Pairing modes.
- Dark, light, and split-background tests.
- Per-face casing, role, Keep / Maybe / Reject decision, notes, and tags.
- Study-level alignment, tracking, line height, metadata, and guides.
- Every CoreText variable axis exposed with its real bounds.
- CoreText OpenType feature selectors exposed when the font provides them.
- Script-coverage probes and missing-scalar warnings.

Coverage is diagnostic, not magical. A font containing the required Unicode scalars can still shape a complex script badly. The app says so instead of pretending otherwise.

### Save and hand off

A `.pitchfontstudy` file is readable JSON. It stores decisions and relative source paths where possible; it never embeds font binaries.

Exports can include:

- PNG boards at 1920 × 1080, 2576 × 1080, 3840 × 2160, or 5152 × 2160;
- one multi-page PDF contact sheet;
- a privacy-safe JSON manifest;
- a human-readable Markdown handoff;
- optional source-font copies behind an explicit permission acknowledgement.

Exports render through the same CoreText engine as the live app. They are not screenshots.

## Build and install

Install Apple command-line developer tools, clone the repository, then double-click:

```text
tools/font-previewer/build-font-previewer-app.command
```

The builder:

1. runs the portable core tests;
2. runs a native smoke test against actual macOS system fonts;
3. builds the release executable;
4. generates the app icon locally;
5. assembles and ad-hoc signs `Font Previewer.app`;
6. verifies the signature;
7. packages and re-extracts the ZIP;
8. verifies the extracted app again;
9. installs it into `/Applications` through a recoverable staging path.

Build without installing:

```bash
tools/font-previewer/build-font-previewer-app.command --no-install
```

Skip tests only when a prior CI run already covered the same commit:

```bash
tools/font-previewer/build-font-previewer-app.command --no-install --skip-tests
```

Output:

```text
tools/font-previewer/output/macos/Font Previewer.zip
tools/font-previewer/output/macos/Font Previewer.zip.sha256
```

For source development:

```bash
cd tools/font-previewer/macos
swift test
swift run FontPreviewer
```

Or double-click:

```text
tools/font-previewer/run-font-previewer.command
```

## Keyboard review

- `1`: Keep
- `2`: Maybe
- `3`: Reject
- `4`: toggle selected face in Compare
- `⌘↑` / `⌘↓`: previous / next visible face
- `⌘I`: import
- `⇧⌘E`: export
- `⌘S`: save

## Search grammar

Plain terms search family, style, PostScript name, file, format, role, decision, axes, tags, notes, and coverage labels.

Field filters can be combined:

```text
tag:warm role:display variable:true
status:keep format:otf
script:devanagari missing:true
```

## Privacy boundary

- No account.
- No network layer.
- No analytics.
- No source hashes in the study or handoff.
- No font binaries inside `.pitchfontstudy`.
- Absolute paths omitted from exports by default.
- Paid or client fonts remain ignored by Git.
- Optional font copying requires a conscious licence acknowledgement.

The app cannot determine what a font licence permits. That remains the user’s responsibility.

## Source map

```text
macos/
├── Package.swift
├── Sources/
│   ├── FontPreviewerCore/      Foundation-only models, migration, search, handoff
│   ├── FontPreviewerMacKit/    CoreText catalogue, renderer, watcher, exporter
│   ├── FontPreviewerApp/       SwiftUI macOS application
│   └── FontPreviewerSmoke/     native end-to-end smoke executable
├── Tests/
│   ├── FontPreviewerCoreTests/
│   └── FontPreviewerMacKitTests/
└── Support/                    Info.plist and generated-icon source
```

Read next:

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- [`docs/QA.md`](docs/QA.md)
- [`docs/OPEN_SOURCE_NOTES.md`](docs/OPEN_SOURCE_NOTES.md)
- [`ROADMAP.md`](ROADMAP.md)
- [`CHANGELOG.md`](CHANGELOG.md)

## Legacy browser experiments

These remain for archaeology and comparison only:

```text
typeboards.html
figma-font-test-exporter.html
start-font-previewer.sh
```

Do not extend both products in parallel. New product work belongs in the native macOS app.
