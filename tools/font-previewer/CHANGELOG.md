# Changelog

## 0.3.0 — Native macOS lab

### Added

- Native SwiftUI macOS application with CoreText rendering.
- File and recursive folder import without font installation.
- OTF, TTF, TTC, OTC, dfont, WOFF, and WOFF2 candidate support through CoreText.
- Collection-face identity and duplicate handling by canonical source plus face index.
- Review, Focus, Compare, Waterfall, Metrics, Glyphs, and Pairing modes.
- Pitch-deck specimen presets, multilingual probes, numerals, and legal text.
- Dark, light, and split specimens.
- Keep / Maybe / Reject decisions, roles, tags, notes, casing, ordering, and search grammar.
- Variable-axis and CoreText feature controls.
- Metrics and script-coverage snapshots.
- Source watching, missing-source state, Finder reveal, and relinking.
- Versioned `.pitchfontstudy` JSON documents with schema-2 migration.
- Delayed autosave guarded by document generation and destination.
- Atomic PNG, PDF, JSON, Markdown, and optional source-font exports.
- Privacy-default handoffs with absolute paths omitted.
- Explicit permission gate for copying source fonts.
- Native smoke executable using real macOS system fonts.
- macOS test suite, CI workflow, generated app icon, ad-hoc signing, and verified packaging.

### Fixed

- Removed duplicate `*Fixed.swift` implementations and the split package-manifest workaround.
- Stopped treating PostScript names as unique face identity.
- Preserved review state across source reload and relink.
- Kept stale autosave work from crossing document boundaries.
- Deduplicated source watchers for collection faces.
- Replaced browser download bursts with one transactional export folder.
- Removed client-specific sample copy from defaults.

### Known limits

- macOS 13 or newer only.
- CoreText shaping only; no HarfBuzz comparison yet.
- Coverage probes do not prove high-quality complex-script shaping.
- Ad-hoc signed and not notarised.
