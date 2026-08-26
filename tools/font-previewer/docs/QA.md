# Font Previewer QA

## Automated gates

Every macOS CI run must pass:

1. portable core tests;
2. macOS CoreText tests against actual system font files;
3. renderer tests for every preview mode;
4. export tests for dimensions and privacy defaults;
5. permission-gate tests for source-font copying;
6. the native smoke executable;
7. release compilation;
8. Info.plist lint;
9. ad-hoc code signing and strict verification;
10. ZIP integrity;
11. archive extraction and a second signature / bundle verification.

The local builder runs the same test and smoke paths before packaging unless `--skip-tests` is explicitly supplied.

## Manual visual matrix

Automation cannot judge typography. Before merge or release, test with fonts the team is legally allowed to use across this matrix.

### Payloads

- static OTF with CFF outlines;
- static TrueType;
- variable font with `wght` only;
- variable font with at least two axes;
- TTC or OTC with multiple faces;
- WOFF and WOFF2 that CoreText accepts;
- font with ligatures and stylistic sets;
- font missing ₹, €, em dash, or accented Latin;
- font covering Arabic, Devanagari, Hebrew, Thai, Japanese, or Korean;
- deliberately colliding PostScript names in different files.

### Workflows

- drag one file;
- drag a folder with nested folders and hidden files;
- import the same source twice;
- save next to fonts and confirm relative paths;
- Save As into another directory and reopen;
- rename or remove a source, reopen, and relink;
- modify a source file while the app is open;
- cancel a large import;
- cancel a multi-page export;
- quit with unsaved changes;
- open a study by double-clicking it in Finder.

### Visual checks

For each representative font:

- title at short and long lengths;
- paragraph with several lines;
- numerals, currency, punctuation, and legal text;
- dark, light, and split backgrounds;
- left, centre, right, and justified alignment;
- negative and positive tracking;
- tight and loose line height;
- every variable-axis extreme and default;
- feature selectors on and off;
- missing-scalar warning;
- Waterfall rows;
- Metrics guide accuracy;
- Glyph cell centring and labels;
- Pairing hierarchy and body readability;
- live canvas versus PNG and PDF.

## Accessibility checks

- Full keyboard review using `1`, `2`, `3`, `4`, `⌘↑`, and `⌘↓`.
- VoiceOver announces family, style, decision, and role for list rows.
- Buttons have labels beyond icon shape.
- The interface remains usable with increased contrast and reduced transparency.
- Status is never communicated by colour alone.
- The window works at its minimum 1080 × 700 size.

## Performance thresholds

These are product guards, not benchmarks to game:

- importing 500 ordinary static faces must keep the main interface responsive;
- scrolling 100 visible review cards must not trigger font-file reads per frame;
- source watching opens one descriptor per unique source, not per collection face;
- exports must release bitmap contexts page by page;
- cancellation must remove hidden staging output.

## Release checklist

- [ ] Core and macOS tests green.
- [ ] Smoke output inspected.
- [ ] At least 20 legally held production fonts reviewed manually.
- [ ] One variable family and one collection tested.
- [ ] One complex-script specimen reviewed by a competent reader.
- [ ] PNG and PDF compared against live rendering.
- [ ] No source font, study, export, or absolute client path staged in Git.
- [ ] README and changelog match the build.
- [ ] ZIP checksum generated.
- [ ] Extracted app launches on a clean macOS user account.
- [ ] Gatekeeper behaviour documented for the ad-hoc build.
