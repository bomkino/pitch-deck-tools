# Deck Prototyper Changelog

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
