# Deck Prototyper Next Fixes

This is the working list distilled from the current prototyper feedback. Keep it updated with each version so the scattered rough edges do not disappear between passes.

## Already Improved

- Project reset now backs up the current working files before starting over.
- New/reset slides default to one image via the full-bleed layout.
- Script tab can add slides, move slides with buttons, and drag/drop reorder slides.
- Script text can be synced from the browser back to `deck-copy.txt`, and reloaded from the file.
- Assembly now has one selected-slide media panel instead of the old Mains/Backups tab split.
- Curation right-click menu is now a flat direct-action menu with viewport edge detection.
- Assembly now has explicit media slot cards and per-slot pan/scale/mirror state.
- Assembly now has image-edge preview, fit width/height controls, and edge alignment controls.
- Script now has explicit delete-slide support and clearer two-way sync wording.
- Script cards now show word counts, media counts, direct Curation/Assembly jumps, and clearer file sync status.
- Export now has Deck Health preflight with blockers, warnings, issue jumping, and export warnings.
- Curation, Lightbox, Assembly navigation, and spec export now escape deck copy consistently.
- Curation now has a target summary, per-slide status rail, next-issue shortcut, and one-click media-card assignment.

## Highest Priority

1. Assembly should feel native and dependable.
   - Make media slots explicit for 0, 1, 2, and grid layouts.
   - Let the user pick a slot, replace media, remove media, and reorder media without state confusion.
   - Keep canvas controls stable while changing between one image and two images.
   - Add per-slot crop/pan/scale instead of one global image transform.

2. The right sidebar should stop jumping.
   - Use one stable rail width per tab.
   - Keep controls in predictable sections.
   - Avoid changing the whole sidebar structure for tiny mode changes.

3. Curation and lightbox should feel like one workflow.
   - Preserve the selected target slide when moving between grid and lightbox.
   - Make right-click, keyboard shortcuts, and lightbox buttons perform the same actions.
   - Keep menu and lightbox actions visible near screen edges.
   - Add a GIF static-frame picker instead of relying on the browser thumbnail.

## Known Pain Points From Feedback

- Tab 1 is improved, but still needs duplicate controls and a better long-body editing surface.
- Tab 1 supports adding, deleting, and reordering slides; it now needs smaller polish.
- Media count per slide is too hard to understand and should default to one image.
- Sync between the web app and notepad file needs clearer two-way intent and conflict handling.
- Tab 2 right-click behavior was brittle, especially near viewport edges.
- Curation jumps too much when entering the lightbox flow.
- Export now has a preflight layer, but visual export still needs better progress and failure details.
- Tab 3 is the most important and still needs the deepest rebuild.
- Switching a slide from one image to two images can leave the canvas and saved state feeling confused.
- The old Mains/Backups assembly model felt weird and weak.
- GIFs need a real flow: choose/use a static frame for the slide, while preserving that the source is a GIF.
- Export/preflight still needs a reliability pass after Assembly is stable.
- Versioning, changelog, backups, and optional GitHub publishing should stay explicit for each pass.

## Suggested Version Plan

- `v0.9.0`: GIF static-frame picker, export progress, failure details, and final deck quality checks.
- `v1.0.0`: Deeper script sync conflict preview and first stable Mac release.

## GitHub Policy

Do not push automatically after every version. Commit/push when the user asks for a checkpoint or release. Each push should include the version bump, changelog entry, and a short summary of what changed.
