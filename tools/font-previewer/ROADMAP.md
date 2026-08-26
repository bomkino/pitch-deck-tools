# Font Previewer Roadmap

## Release gate

- Make the macOS CI and smoke gauntlet green.
- Inspect the app on physical Apple-silicon and Intel Macs where available.
- Review the interface with 20–50 real production fonts.
- Fix any live-versus-export divergence before merging.
- Publish an ad-hoc signed release ZIP and checksum.

## Next product pass

- Save named specimen recipes inside a study.
- Add multi-select and bulk role / tag editing.
- Add a family view that groups related static faces without collapsing them.
- Add a dedicated fallback-stack and cascade tester.
- Add a side-by-side live diff for two selected fonts at identical fitted and identical absolute sizes.
- Add export annotations for client-facing rationale.
- Improve feature naming for common OpenType tags while retaining CoreText IDs.
- Add crash-safe recovery snapshots separate from intentional project saves.

## Typography research

- Build a shaping corpus for Arabic, Devanagari, Hebrew, Thai, and selected Southeast Asian scripts.
- Evaluate a small HarfBuzz bridge against CoreText output before choosing a dependency.
- Explore optical-size presets and named variable instances.
- Add deck-relevant vertical-metric and punctuation preflight checks.
- Investigate UFO, Designspace, and TTX only if font-development workflows become a real user need.

## Handoff

- Define a stable Figma handoff rather than a fake “export to Figma” button.
- Consider copying CSS variation and feature settings for web-deck work.
- Add an optional contact-sheet SVG only after text-to-path and font-licence implications are explicit.

## Distribution

- Developer ID signing and notarisation.
- Universal binary or separate verified arm64 / x86_64 builds.
- Sparkle-style updates only if they can remain opt-in, private, and dependency-light.

## Not planned

- Cloud font storage.
- Accounts or analytics.
- Automatic “best font” scores.
- Generative font imitation.
- Silent copying or packaging of source fonts.
- Maintaining the legacy HTML and native app as equal products.
