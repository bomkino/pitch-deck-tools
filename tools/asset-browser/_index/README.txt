pitch.dog · asset toolkit
=========================

Five scripts live at the project root. Double-click any of them.

────────────────────────────────────────────────────
  DAILY USE
────────────────────────────────────────────────────
Double-click open-index.command. That's it.
A Terminal window opens, browser opens at http://localhost:8765,
you see all your bundles. Keep the Terminal window open while
you work. Close it when done for the day.

The local web server is the reason "Reveal in Finder" works
natively now (clicking it actually opens Finder, instead of
the browser trying and failing). It's also why previews keep
loading after you click around.

────────────────────────────────────────────────────
  EVERYTHING ELSE
────────────────────────────────────────────────────
index-assets.command      Manually re-scan the folder for new bundles.
                          You rarely need this — the ↻ Refresh button
                          in the browser does the same thing.

consolidate-fonts.command Collect the best version of every font into
                          _index/fonts-to-install/, then opens that
                          folder. Cmd+A → drag into Font Book.

live-updates-on.command   Set up a background watcher that re-scans
                          every 60 seconds. Reload the browser to see
                          changes. Useful if you're dropping new
                          downloads constantly.

live-updates-off.command  Turn off the background watcher.

────────────────────────────────────────────────────
  WHAT'S NEW IN v3
────────────────────────────────────────────────────
  · Local web server fixes "Open in Finder" (was broken in v2).
  · Up to 16 preview thumbnails per bundle (was 6).
  · ↻ Refresh button in the browser — no need to re-run scripts.
  · Loose photos at the top of Photos/ are now indexed.
  · Tags, "used in", notes per bundle (in the lightbox).
  · Filter by category, file type, tag, used-in. Sort by date/size.

────────────────────────────────────────────────────
  TAGS — KEEP THEM SAFE
────────────────────────────────────────────────────
Tags live in your browser. Click "Export tags" in the header,
save the downloaded tags.json into Assets/_index/ — the indexer
picks it up on the next run. Do this once a week.

────────────────────────────────────────────────────
  REUSING ON OTHER PROJECTS
────────────────────────────────────────────────────
Look in your Downloads (or wherever) for the
"pitchdog-asset-toolkit" folder. That's the portable version.
Duplicate it for each new project, drop assets inside,
double-click open-index.command. Full instructions are in
START-HERE.txt inside the toolkit folder.

────────────────────────────────────────────────────
  LAYOUT
────────────────────────────────────────────────────
  Assets/
  ├── open-index.command           ← daily driver
  ├── index-assets.command
  ├── consolidate-fonts.command
  ├── live-updates-on.command
  ├── live-updates-off.command
  ├── Patterns/                    ← your source assets
  ├── Posters/
  ├── Fonts/
  ├── Photos/
  ├── Text Effects/
  └── _index/
      ├── index.html               (the page; served via localhost)
      ├── tags.json                (export from browser, drop here)
      ├── fonts-report.txt
      ├── fonts-to-install/
      ├── thumbs/
      └── _scripts/
          ├── server.py            (the local web server)
          ├── index_assets.py
          ├── consolidate_fonts.py
          └── template.html
