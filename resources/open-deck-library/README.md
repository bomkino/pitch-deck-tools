# pitch.dog Open Deck Library · V3.2.0

**Nineteen free, route-specific pitch-deck systems for film, television and commercial director treatments. No email gate. No account gate. No hidden paid tier.**

The library is for people who need to make a serious deck before they can afford a professional deck team. It cannot manufacture rights, access, attachments, authority, finance or outcomes. It can remove the blank page, teach the argument, expose unsupported claims and carry a creator from first decisions to an inspectable PDF.

## The Gold Pack contract

Every route generates one self-contained pack containing:

- **Quick** — the shortest responsible first cut;
- **Clean** — the full route without teaching rails;
- **Annotated** — page prompts, fictional examples and deletion rules;
- **Sample** — a completely written fictional project with original procedural art;
- a **22-page Gold Playbook**;
- an **18-question copy interview**;
- a route-specific image brief and provenance log;
- Canva-importable HTML, editable PPTX, PDF examples and plain-text source;
- one explicit order of operations and one final cold-read gate.

## Routes

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

## Verified scope

- 19 route systems;
- 76 editable route masters across four editions;
- 19 route playbooks / 418 pages;
- 10 deep guides / 409 pages;
- 48 verified Canva designs / 2,074 pages;
- 48 PPTX/PDF page-parity checks;
- 76 / 76 editable masters clear the overflow gate;
- 19 / 19 playbooks clear the overflow gate;
- 19 / 19 route packs clear the unchanged consumer simulation;
- 488 deterministic checks, zero warnings, zero failures;
- zero cross-route sample-copy collisions and zero unallowlisted playbook collisions.

## Canva workbench

Current team workbench:

**https://www.canva.com/folder/FAHS1HdvTRw**

The workbench has been read back as 48 designs / 2,074 pages. Its view links are recorded in `canva-live-public.json`. They are not represented as permanent public template-copy links. The downloadable HTML and PPTX sources remain the durable redistribution path.

## Reconstruct the source

The complete tested source is stored as ordered Base64 chunks because this connector cannot upload a binary archive directly.

```bash
cd resources/open-deck-library/source
cat open-deck-library-v3.2.0-source.part-*.b64 \
  | base64 --decode \
  > open-deck-library-v3.2.0-source.tar.xz

echo "9da7989d19a55baedfc2a317bf644c38b7633191747e13d884fb49757fe04248  open-deck-library-v3.2.0-source.tar.xz" \
  | sha256sum -c -

mkdir ../worktree
tar -xJf open-deck-library-v3.2.0-source.tar.xz -C ../worktree
cd ../worktree
npm ci
npm run build
npm run verify
```

On macOS, use `shasum -a 256` instead of `sha256sum`.

## Full release build

The release pipeline requires Node.js 22+, Python 3 and LibreOffice for PDF export.

```bash
npm ci
npm run build
npm run verify
npm run release
python scripts/consumer_test.py
python scripts/phrase_collision_test.py
```

The release command produces 19 route Gold Packs, Film / Television / Treatment category packs, Guides, Canva Imports, Source and Full ZIPs, plus manifests and SHA-256 sums.

## Material boundaries

All sample projects are fictional teaching artifacts. Do not convert fiction into a public claim. Mark live facts as confirmed, pending, aspirational, unknown or not applicable.

Do not use the library to fabricate:

- talent attachments;
- underlying rights;
- documentary access;
- participant consent;
- budget certainty;
- audience or market proof;
- commissioning, financing, distribution or award outcomes;
- personal connection or cultural authority.

Unknown is cleaner than invented.

## Licence

- Generator code: **MIT**.
- Original template copy, layouts, procedural art and guides: **CC0 1.0 Universal**.
- `pitch.dog` name and marks: reserved.
- Font files are not distributed.
