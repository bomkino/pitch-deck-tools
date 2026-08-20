<p align="center">
  <img src="dist/previews/00_LIBRARY_COVER_GRID.jpg" alt="Nineteen route-specific Open Deck Library systems" width="100%">
</p>

# pitch.dog Open Deck Library

**Free, route-specific pitch-deck systems for film, television and director treatments. No account gate. No email capture. No strings.**

The library is built for people who need to make a serious deck before they can afford a professional deck team. It does not promise that a template will fund, sell, commission or award a project. It gives the work a stronger structure, a clearer truth system and an editable visual foundation.

## What is here

- **19 route systems** across film, television and commercial director treatments.
- **4 editions per route:** fictional Sample, teaching Annotated, blank Clean and minimum viable Quick.
- **76 editable PPTX masters** and **76 Canva-importable HTML masters**.
- **19 plain-text route sources**.
- **10 deep guides**, including Truth + Proof, Copy, Image, Genre, Layout, Live / Leave-Behind, Deck Surgery, Swiss Grid and Canva release workflow.
- **19 sample PDFs** and **10 guide PDFs**.
- Original procedural artwork. No stock bundle, scraped stills, celebrity likenesses, paid Canva assets or hidden source images.
- Reproducible generator, manifest, hashes and automated verification.

The earlier V2 Canva library remains a separate sample corpus: **24 masters, 732 pages**. V3.1 is the durable workbench generated from source.

## Choose an edition

| Edition | Use it for | What it contains |
|---|---|---|
| **Sample** | Learn | Fully written fictional example + original visual system. Do not keep fictional facts. |
| **Annotated** | Decide | Page prompts, why-the-page-exists rail, fictional example and deletion rule. |
| **Clean** | Build | Full route without teaching rails. |
| **Quick** | Finish | The shortest responsible route. Add pages only when a reader problem demands them. |

## Choose a route

### Film

1. Feature Drama — **LOW TIDE**
2. Feature Horror — **AFTERLIGHT**
3. High-Concept Feature — **NORTHBOUND**
4. Fiction Short — **ELEVEN MINUTES**
5. Documentary Feature — **THE RIVER KEEPS RECEIPTS**
6. Documentary Short — **LAST SHIFT**

### Television

7. Returning Drama — **SIGNAL HOUSE**
8. Limited Series — **THE QUIET CALENDAR**
9. Half-Hour Comedy — **RENT CONTROLLED**
10. Unscripted Format — **SECOND DRAFT**
11. Documentary Series — **THE LAST CROSSING**
12. Animation / Kids — **MOON MOTH POST**

### Director treatments

13. Performance / Beauty — **HUMAN WEATHER**
14. Food / People — **COMMON TABLE**
15. Comedy — **DEADPAN**
16. Automotive / Action — **MOTION**
17. Product / Tabletop — **OBJECT DESIRE**
18. VFX / Transformation — **WORLD SHIFT**
19. Real People — **REAL WITNESS**

## The first fifteen minutes

1. Pick the route by truth mode and reader—not by colour.
2. Open the **Quick** edition.
3. Replace project, premise / engine / take, story, people, current truth and exact ask.
4. Delete anything unsupported.
5. Export PDF.
6. Ask a cold reader to state the project, pressure, people, experience, status and next action.
7. Move to Annotated or Clean only when the short deck reveals a real missing proof.

## Verified Canva workbench

V3.1 has been imported and read back from Canva as **29 designs / 1,656 pages**:

- 6 Film workbooks / 400 pages;
- 6 Television workbooks / 395 pages;
- 7 Director Treatment workbooks / 452 pages;
- 10 guides / 409 pages.

**Workbench:** https://www.canva.com/folder/FAHS0r0uGq0

Each route workbook contains Sample, Annotated, Clean and Quick editions in one design. These are current team-editable Canva designs, not a promise that the links are permanently public template links. The HTML and PPTX sources remain the durable, redistributable release.

## Canva

Each route includes a self-contained HTML import and an editable PPTX.

1. In Canva, choose **Create a design → Import file**.
2. Import the PPTX or HTML.
3. Make a copy.
4. Replace truth before styling.
5. Remove annotation rails before sending.
6. Export PDF and inspect the exported file.

Canva is an editing surface, not the archive. Keep the source folder, manifest and exported PDF together.

See [`docs/CANVA_IMPORT_AND_RELEASE.md`](docs/CANVA_IMPORT_AND_RELEASE.md).

## Build and verify

Requires Node.js 22+ and `pptxgenjs`.

```bash
npm install
npm run build
npm run verify
```

Verification checks:

- exact route, edition and guide counts;
- PPTX archive integrity and slide counts;
- HTML / PPTX page parity;
- 16:9 dimensions;
- invalid output tokens and local-path leaks;
- no bundled font files;
- V2 catalog count and page-total drift.

The release also includes LibreOffice PDF parity and visual duplicate reports in `qa/`.

## Structure

```text
src/                  route data, guide data, art and generators
dist/templates/       Sample, Annotated, Clean, Quick, HTML and text
dist/guides/          editable guides + HTML + text
dist/pdf/             sample and guide PDFs
dist/previews/        contact sheets and cover grid
dist/manifests/       machine-readable release data and hashes
docs/                 human handoff and craft guidance
site/                  static gallery for GitHub Pages
qa/                    build, verification, PDF parity and gauntlet receipts
```

## Licensing

- Generator code: **MIT**.
- Original copy, layouts, procedural art and guides: **CC0 1.0 Universal**.
- pitch.dog name and marks: reserved.
- Font files are not distributed.

Read [`CONTENT-LICENSE.md`](CONTENT-LICENSE.md) and [`TRADEMARKS.md`](TRADEMARKS.md).

## Material boundaries

The sample projects are fictional. They are teaching artifacts, not claims about real people, access, rights, attachments, finance or outcomes.

Do not use the library to fabricate:

- talent attachments;
- rights or permissions;
- documentary access;
- budget certainty;
- audience or market proof;
- awards, commissioning or funding outcomes;
- personal connection or cultural authority.

Unknown is cleaner than invented.
