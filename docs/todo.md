# Pitch Deck Tools To-Do

Last updated: 2026-08-26

## Priority 1: Font Previewer native macOS release

Goal: replace the browser experiment with a dependable local typography lab for pitch-deck decisions.

Reached on `codex/native-macos-font-lab`:

- native SwiftUI / CoreText architecture split into Core, MacKit, App, and Smoke targets;
- direct file and recursive folder import without installing fonts;
- static, variable, and collection-face handling through CoreText;
- pitch-specific specimen presets;
- Review, Focus, Compare, Waterfall, Metrics, Glyphs, and Pairing modes;
- dark, light, and split backgrounds;
- roles, decisions, tags, notes, casing, search grammar, and ordering;
- variable axes and CoreText feature selectors;
- metrics, script probes, missing-scalar diagnostics, source watching, and relinking;
- schema-versioned `.pitchfontstudy` files with migration and relative paths;
- cancellable, atomic PNG / PDF / JSON / Markdown exports;
- privacy-default handoffs and a licence acknowledgement before source-font copying;
- core tests, macOS tests, native smoke tests, builder, generated icon, signing, packaging, and CI workflow.

Release gate:

- make the macOS CI pass on the actual branch;
- fix all Apple-only compiler and runtime failures exposed by CI;
- inspect a CI-built app on a physical Mac;
- manually review 20–50 legally held production fonts;
- compare live output against PNG and PDF;
- test one variable family, one collection, and one complex-script font with a competent reader;
- merge only after the manual matrix in `tools/font-previewer/docs/QA.md` is complete.

Next product pass:

- named specimen recipes;
- multi-select and bulk role / tag editing;
- family grouping without identity collapse;
- fallback-stack and cascade testing;
- two-font identical-size versus fitted-size diff;
- client-facing rationale annotations;
- crash-recovery snapshots;
- Developer ID signing and notarisation.

Research later:

- measured CoreText versus HarfBuzz shaping corpus;
- optical-size and named-instance workflows;
- deck-relevant vertical-metric and punctuation preflight;
- stable Figma / web handoff;
- UFO and Designspace only if font-development workflows become a real need.

## Priority 2: Deck Prototyper stability

Immediate:

- stabilise Assembly when switching between one and two media slots;
- make GIF handling explicit with a static-frame choice;
- improve copy-sync conflict preview;
- reduce layout jumping and preserve right-panel scroll positions;
- strengthen export preflight for missing media, overflow, empty slides, and local-file errors.

Later:

- sample projects with safe reset;
- documented, discoverable shortcuts;
- a headless export path if browser export remains limiting.

## Priority 3: Asset Browser

Immediate:

- improve first-run guidance;
- make missing optional helpers less alarming;
- clarify open / reveal failures when the OS blocks them.

Next:

- intentional tag import / export;
- better duplicate review;
- saved filters for deck work;
- richer font consolidation reports.

## Cross-project

- Keep docs beginner-readable without hiding real constraints.
- Keep private media, fonts, studies, exports, and client paths out of Git.
- Keep changelogs and release gates current.
- Add smoke tests before calling a tool dependable.
- Prefer one tested product path over two half-maintained implementations.

Definition of done for a useful batch:

1. The change works on its target platform.
2. Automated tests and smoke gates pass.
3. The relevant manual visual check is complete.
4. Docs explain use, boundaries, and failure states.
5. No private file or path is staged.
6. A reviewable branch and pull request exist before merge.
