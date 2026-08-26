# Open-source Notes

This app learns from open-source typography tools without copying their interfaces or source wholesale.

## FontGoggles

Useful lessons:

- open files and folders directly;
- treat collections as multiple faces;
- reload a source when it changes;
- test real variable behaviour instead of static thumbnails;
- complex-script shaping deserves an explicit engine and test corpus.

FontGoggles supports more source formats and uses HarfBuzz. Font Previewer currently chooses a smaller CoreText-only boundary because its first job is deck typography on macOS, not font development. HarfBuzz remains a serious future direction, not a checkbox.

## FontBlind

Useful lessons from our own project:

- local-only should be enforced in architecture;
- native file panels are better than browser upload facsimiles;
- builders should stage installation, preserve the old app, sign nested output, package, extract, and verify;
- privacy claims need output-level tests;
- refusal is better than silently producing an untrustworthy artefact.

Font Previewer borrows those operational standards, not FontBlind’s transformation logic or interface.

## fontTools

fontTools remains the obvious future route for richer OpenType metadata, design-space inspection, and source-format support. It is not bundled in the native app today because CoreText already covers the product’s first release boundary without a Python runtime.

## FontBakery

FontBakery’s broad, explicit checks are a useful model for future preflight diagnostics. Font Previewer should not become a compliance dashboard, but it can eventually surface a small deck-relevant subset: broken names, missing common punctuation, implausible vertical metrics, and variation-axis anomalies.

## DrawBot

DrawBot demonstrates how valuable repeatable specimen scripts can be. Font Previewer’s JSON study and single rendering engine create the foundation for shareable specimen recipes without forcing users to write Python.

## Apple frameworks

CoreText supplies descriptor loading, variation axes, features, metrics, shaping, and drawing. AppKit supplies font-aware file panels, Finder integration, source watching, and app packaging. SwiftUI supplies the workspace, but does not own typography rendering.

## Non-goals

- Reproducing another tool’s visual language.
- Adding a dependency merely because it is famous.
- Claiming script support from Unicode coverage alone.
- Generating subjective “best font” scores.
- Training on or uploading paid fonts.
