# Pitch Deck Tools To-Do

Last updated: 2026-06-28

This is the working list for the next development passes. The next priority is Font Previewer.

## Priority 1: Font Previewer

Goal: make the Font Previewer feel like a proper local typography lab for pitch decks.

Immediate:

- Redesign `typeboards.html` so importing fonts, comparing fonts, and changing sample text feel calm and obvious.
- Add pitch-deck sample text presets: title slide, logline, one-line promise, investor problem statement, quote, team bio, data label, caption, and legal/footer text.
- Add a fixed comparison layout so panels do not jump around while fonts load.
- Show basic font metadata when possible: family name, style, file name, weight guess, format, and source file.
- Add a simple saved set format for local comparison boards.
- Add export options for PNG/PDF or clean print-to-PDF layouts.

Next:

- Add a local font folder scan mode for offline work.
- Add a stronger Figma handoff path from `figma-font-test-exporter.html`.
- Add readability checks at common deck sizes.
- Add dark/light background checks.
- Add a compact mode for comparing many fonts quickly.

Later:

- Add font pairing suggestions.
- Add brand-tone tags such as warm, technical, cinematic, editorial, luxury, playful, and institutional.
- Add sample deck templates that use selected fonts.

## Priority 2: Deck Prototyper Stability

Goal: keep turning the prototyper from fragile into dependable.

Immediate:

- Stabilize Assembly when switching between one and two media slots.
- Make GIF handling explicit: choose a static frame for slide placement, keep the source marked as GIF.
- Add a clearer sync flow between `deck-copy.txt` and the Script tab, including conflict preview.
- Reduce layout jumping between Curation, Lightbox Curation, and Assembly.
- Make right-side panels keep stable widths and scroll positions.

Next:

- Improve media slot assignment from curation into assembly.
- Add stronger export preflight checks for missing media, overflows, empty slides, and local file errors.
- Add a clearer visual state for selected slide, selected media, and active slot.
- Add a browser smoke-test checklist for Mac, Linux, and Brave Browser Beta.

Later:

- Add sample projects that can be loaded/reset safely.
- Add keyboard shortcuts only where they are discoverable and documented.
- Add a real headless export path if browser export becomes limiting.

## Priority 3: Asset Browser

Goal: make asset organization reliable for messy real projects.

Immediate:

- Improve the first-run state so users know where to put assets and how to rebuild the index.
- Make missing optional helpers less scary on Linux.
- Add clearer messages for open/reveal actions when the OS blocks them.

Next:

- Add import/export for tags when a team wants shared metadata.
- Add a better duplicate-finding view.
- Add saved filters for deck work: stills, posters, textures, fonts, screenshots, videos, references.

Later:

- Add optional project profiles.
- Add better browser-side review/shortlist workflows.
- Add richer font consolidation reports.

## Cross-Project

Immediate:

- Keep docs noob-friendly and GitHub-first.
- Keep private media, fonts, exports, and client files ignored.
- Keep app versions and changelogs current.
- Keep an offline handover folder refreshed after major merges.

Next:

- Add simple smoke tests for each app.
- Add issue templates for bug reports and feature requests.
- Add a release checklist.
- Add short demo videos or GIFs for each app.

Definition of done for a useful batch:

1. The change works locally.
2. The docs tell a beginner how to use it.
3. Private files are not staged.
4. GitHub `main` has the latest merged version.
5. The offline handover folder is refreshed when needed.

