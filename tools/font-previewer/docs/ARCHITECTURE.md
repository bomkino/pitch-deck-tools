# Font Previewer Architecture

## Product boundary

Font Previewer is a Mac-only desktop application, not a hosted web app in a wrapper. The product boundary is deliberate:

- fonts stay local;
- CoreText supplies the same shaping and variation behaviour used by the renderer and exporter;
- native file panels, Finder reveal, source watching, document opening, keyboard commands, and app packaging are first-class;
- no browser download hacks or local web server remain in the primary workflow.

## Layers

### `FontPreviewerCore`

Foundation-only and portable. It owns:

- versioned `.pitchfontstudy` models;
- schema migration and validation;
- relative path resolution;
- canonical source-path-plus-face identity;
- title-case transforms;
- specimen presets;
- search and field filters;
- ordering, comparison, and pairing rules;
- export planning;
- privacy-safe JSON and Markdown handoff generation.

This target compiles and tests on Linux. It must not import AppKit, SwiftUI, CoreText, or ImageIO.

### `FontPreviewerMacKit`

macOS typography and file I/O. It owns:

- CoreText descriptor loading;
- collection-face enumeration;
- variable-axis extraction;
- OpenType feature extraction and application;
- metrics and script probes;
- source-file watching;
- all live and export rendering;
- PNG, PDF, JSON, Markdown, and optional font-copy transactions.

`RuntimeFontFace` deliberately stays out of saved studies. It is reconstructed from the source file when a document opens.

### `FontPreviewerApp`

SwiftUI interaction and macOS lifecycle. It owns:

- the three-column workspace;
- review controls and inspector;
- import, relink, open, save, and export panels;
- keyboard commands;
- document dirty state and delayed autosave;
- cancellation and progress;
- unsaved-change protection.

### `FontPreviewerSmoke`

A native executable used by CI and the local builder. It locates real macOS system fonts, imports multiple faces, renders every scene, exports a complete handoff, verifies image dimensions, checks the PDF payload, and asserts that privacy-default JSON contains no system font path.

## Rendering contract

There is one renderer: `BoardRenderer`.

The SwiftUI canvas hosts an `NSView` that calls it. `BoardExporter` calls the same renderer against bitmap and PDF contexts. A live preview therefore cannot quietly diverge from its exported board because of a second implementation.

Current scenes:

- Review / Focus specimen
- four-up Compare
- Waterfall
- Metrics
- Glyph grid
- Pairing / deck-stage composition

## Font identity

PostScript names are not unique enough. Different revisions, vendors, collection faces, or deliberately anonymised fonts can collide.

The stable import identity is:

```text
canonical source URL + face index
```

Relative project paths resolve against the study location before de-duplication. A TTC or OTC preserves every face.

## Variable fonts and features

CoreText returns variation axes using numeric axis identifiers. The app stores both the identifier and the readable four-character tag. Rendering creates a font with:

1. the original descriptor;
2. selected CoreText feature selectors;
3. selected variation values;
4. the requested point size.

Axis bounds are clamped on load and relink. Feature selections survive only when the replacement face still exposes the same selector.

## Documents

`.pitchfontstudy` is pretty-printed JSON with an explicit schema version. Schema 2 studies migrate to schema 3 defaults. Future schemas are refused rather than partially misread.

The document stores source paths, not font payloads. Paths become relative when the study and font share a useful root. Saving As rewrites paths from the old document location to the new one without changing the actual source URL.

Autosave captures both its destination URL and a document-generation token. A delayed save from an earlier document cannot land in a newly opened study.

## Concurrency

CoreText catalogue work, document rehydration, and export run outside the main actor. The interface receives only committed results and progress updates.

Document transitions cancel import, export, reload, and autosave tasks. Export checks cancellation between every rendered page and copied source file.

## Export transaction

Export is all-or-nothing:

1. validate selected records and runtime faces;
2. create a hidden staging directory inside the chosen destination;
3. render requested files;
4. write handoffs;
5. optionally copy each unique source file;
6. check cancellation;
7. move the complete staging directory into a collision-safe final name.

Failure or cancellation deletes staging. Existing exports are never overwritten.

## Privacy

Privacy is architectural, not a copy claim:

- no network dependency exists;
- runtime descriptors are ephemeral;
- saved studies contain no font bytes;
- handoffs omit absolute paths unless explicitly requested;
- source-font copying is off and permission-gated;
- local studies, font files, and exports are Git-ignored.

## Why not HarfBuzz yet

FontGoggles demonstrates the value of HarfBuzz for complex-script realism and source formats such as UFO and Designspace. This app currently uses CoreText to keep the first native release small, explainable, and dependency-free. Script coverage is therefore labelled as a probe, not proof.

A HarfBuzz-backed shaping comparison belongs behind a measured test corpus, not as a decorative dependency.
