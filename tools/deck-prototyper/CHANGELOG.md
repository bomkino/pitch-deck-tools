# Deck Prototyper Changelog

## v0.8.0 - 2026-06-08

- Added a Curation target summary so the current slide, status, layout, and media count stay visible above the media grid.
- Added a next-issue action and `N` keyboard shortcut for moving through slides that still need visual attention.
- Redesigned the Curation script rail with per-slide status, layout, main-media count, alternate count, and a direct Assembly jump.
- Added one-click Set main actions directly on media cards for the active target slide.
- Kept Lightbox assignment synced with the same target slide summary used in Curation.
- Escaped media badges and folder dropdown labels more consistently.

## v0.7.0 - 2026-06-08

- Added a Deck Health panel in Export with a readiness score, slide stats, blockers, and warnings.
- Added a "Fix first issue" action that jumps directly to the relevant Script, Curation, or Assembly view.
- Added export readiness warnings before media, visual, or spec-sheet export when blockers remain.
- Grouped missing media by slide so older projects do not flood the health panel with duplicate-looking issues.
- Made media search include filename, folder, and path.
- Hardened Curation, Lightbox, Assembly navigation, and spec export text rendering so deck copy is escaped consistently.
- Improved Export tab layout into a two-panel preflight and pipeline workspace.
- Fixed Lightbox target emphasis so the selected slide and active-main state are clearer.

## v0.6.0 - 2026-06-08

- Redesigned the Script tab cards so each slide is easier to scan while editing.
- Added per-slide word counts and media slot counts beside each slide number.
- Added Script card actions to jump the active slide straight into Curation or Assembly.
- Added a visible browser/file sync status for `deck-copy.txt`.
- Changed text edits to save in the browser first, then sync deliberately to `deck-copy.txt`.
- Added a reload warning when browser edits have not been synced to file.
- Exposed the current `deck-copy.txt` source and modified time through the local data API.

## v0.5.0 - 2026-06-01

- Added an Assembly toggle to show the selected image edge while framing media.
- Added fit-width, fit-height, and edge alignment controls for the active media slot.
- Renamed Reset Project to New Project and kept the backup-first reset behavior.
- Made Script tab sync wording explicit with Sync from File and Sync to File.
- Added slide deletion from the Script tab.
- Improved slide drag/drop feedback with before/after drop indicators.
- Added Linux-friendly startup options with `PORT` and `PROTOTYPER_OPEN_BROWSER`.

## v0.4.0 - 2026-06-01

- Added explicit Assembly media slots for full-bleed and split layouts so slide media is no longer just an ambiguous mains list.
- Added active slot selection in the Inspector, with filled/empty slot cards and clearer slot labels.
- Made Assembly media dragging work per active/clicked media slot, including split/grid layouts.
- Moved image scale, pan, and mirror state into per-slot transforms while preserving old full-bleed settings.
- Added slot-aware promote, remove, and left/right reorder behavior so transforms move with their media.

## v0.3.1 - 2026-05-31

- Added smart viewport edge detection to the Curation right-click menu so it opens left/up when near browser edges.
- Updated the right-click menu labels to reflect the active target slide and disabled impossible target-slide actions.
- Removed the old unused hover-submenu code path after replacing it with direct actions.
- Added `NEXT_FIXES.md` as the working problem list and roadmap so user requests stop getting lost between passes.

## v0.3.0 - 2026-05-31

- Started the Assembly redesign around one stable selected-slide editor instead of separate Mains/Backups tabs.
- Added drag-and-drop slide reordering in the Script tab and Assembly slide navigator.
- Replaced the fragile curation right-click hover submenus with a flatter direct-action menu.
- Added GIF labeling in the Assembly media panel so GIF sources are called out as static canvas previews.
- Reduced layout jumping between curation and lightbox rails with a steadier right-side width.

## v0.2.0 - 2026-05-31

- Added a versioned reset flow that backs up `deck-copy.txt`, `manifest.json`, and core prototyper files before starting from one blank slide.
- Added script controls for reloading from `deck-copy.txt`, syncing edits back to file, adding slides, and moving slides up/down.
- Normalized saved slide slots against each layout limit so full-bleed slides default to one main image instead of carrying old multi-main states into Assembly.
- Made the Assembly and Curation sidebars responsive so the canvas/media grid keep usable space in narrow app windows.
- Added isolated test images in `_media/_test_downloads_v0.2/`.
