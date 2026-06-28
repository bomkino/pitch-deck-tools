# Font Previewer

The Font Previewer helps compare fonts quickly for pitch deck design.

## Tools

- `typeboards.html`: drop font files into the page and generate type boards.
- `figma-font-test-exporter.html`: an experimental font testing/export page for Figma-oriented workflows.

## Start On Mac Or Linux

You can open the HTML files directly in your browser:

```text
typeboards.html
figma-font-test-exporter.html
```

Or run a tiny local server:

```bash
./start-font-previewer.sh
```

Then open:

```text
http://localhost:8020/typeboards.html
```

If Linux says `Permission denied`:

```bash
chmod +x start-font-previewer.sh
```

To use another port:

```bash
PORT=8030 ./start-font-previewer.sh
```

## Why It Exists

Deck typography is hard to judge from a font menu. Big type boards make it easier to compare tone, texture, readability, and personality.

## Next Focus

The next major work pass should focus on making this tool feel like a proper font lab for pitch decks:

- clearer font importing
- better sample text presets
- stronger compare views
- saved/exportable type boards
- noob-friendly offline use on Mac and Linux

See the Font Previewer section in `../../docs/todo.md`.
