# Reconstruct the complete V3.1 source archive

The GitHub connector used for this release accepts UTF-8 files but not a local binary archive. The complete tested source tree is therefore stored as ordered Base64 chunks in this directory.

From this directory:

```bash
cat open-deck-library-source.part-*.b64 \
  | base64 --decode \
  > open-deck-library-v3.1.0-source.tar.xz

echo "8297d00ec499e21ca782725cc3d21e6ed254c972aaae23dd52207e92596b1222  open-deck-library-v3.1.0-source.tar.xz" \
  | sha256sum -c -

tar -xJf open-deck-library-v3.1.0-source.tar.xz
```

On macOS, replace `sha256sum` with:

```bash
shasum -a 256 open-deck-library-v3.1.0-source.tar.xz
```

Expected SHA-256:

```text
8297d00ec499e21ca782725cc3d21e6ed254c972aaae23dd52207e92596b1222
```

The archive contains the route data, guide data, procedural-art generator, PPTX/HTML generators, verification code, release scripts, documentation, manifests and QA receipts. Generated PPTX/PDF/ZIP binaries are release artifacts rather than Git source.
