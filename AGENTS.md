# PreviewMD Project Instructions

## Product

PreviewMD is a native, professional macOS Markdown reader owned by Astrography
Sp. z o.o. and authored by Adam Jesionkiewicz (`adam@jesion.pl`).

- Keep the interface native, minimal, and consistent with current macOS design.
- The application targets macOS 14 or newer.
- Release builds must be Universal 2 (`arm64` and `x86_64`).
- The bundle identifier is `pl.jesion.previewmd`.
- The exported Markdown UTI is `pl.jesion.previewmd.markdown`.
- The About window must show the author, email, and copyright year 2026.

## Product invariants

Preserve these behaviors unless the user explicitly requests a change:

- A clean launch opens an empty state, not a default README or demo document.
- The empty state uses the PreviewMD application icon.
- The embedded showcase/demo must work on every supported Mac without relying
  on files from the development machine.
- Closing the final document tab returns to the empty state.
- Files opened from Finder or dropped on the Dock icon open as tabs in the
  existing main window rather than creating unnecessary windows.
- Drag and drop works across the main window.
- The left sidebar is collapsed by default.
- Paper canvas is disabled by default.
- Documents open immediately with the current saved appearance settings; do
  not briefly render with paper canvas or another default layout first.
- Reading width can be adjusted continuously with a clean width control.
- Narrow, comfortable, wide, and table/data presets remain available in the
  menu.
- Tables, Mermaid diagrams, KaTeX, code highlighting, local images, and
  relative links must continue to render offline.

## Building

For a local application bundle:

```bash
./scripts/build-app.sh
```

The local script builds Universal 2. Without
`PREVIEWMD_SIGNING_IDENTITY`, it uses an ad-hoc signature.

Do not replace the Universal 2 build with an architecture-specific binary.
After changing build configuration, verify:

```bash
lipo -info dist/PreviewMD.app/Contents/MacOS/PreviewMD
```

The result must contain both `x86_64` and `arm64`.

## Production signing and notarization

The production signing identity is:

```text
Developer ID Application: Astrography Sp. z o.o. (4NZF9USX28)
```

The Apple Developer Team ID is:

```text
4NZF9USX28
```

The local `notarytool` keychain profile is:

```text
PreviewMD-Notary
```

Never store Apple Account passwords, app-specific passwords, private keys,
certificate exports, or notarization credentials in this repository. The
notarization secret belongs only in the macOS Keychain.

Create a complete release with:

```bash
./scripts/release-app.sh
```

This script must continue to:

1. Build the Universal 2 application.
2. Sign it with Developer ID, Hardened Runtime, and a secure timestamp.
3. Verify the code signature.
4. Submit a ZIP to Apple using `notarytool`.
5. Wait for an `Accepted` result.
6. Staple and validate the notarization ticket.
7. Verify Gatekeeper reports `source=Notarized Developer ID`.
8. Produce the final distributable ZIP in `dist/`.

Only distribute the archive ending in `-macOS.zip`. Never distribute the
temporary archive ending in `-notarization.zip`.

Before handing off a release, confirm:

```bash
codesign --verify --deep --strict --verbose=4 dist/PreviewMD.app
xcrun stapler validate dist/PreviewMD.app
spctl --assess --type execute --verbose=4 dist/PreviewMD.app
```

The most recently accepted release at the time this file was created was
PreviewMD `1.0 (5)`, notarization submission
`49c173da-2c44-464f-93ea-35130bd6d2c4`.

## Versioning

Before each public release, update both values in `scripts/Info.plist`:

- `CFBundleShortVersionString` for the marketing version.
- `CFBundleVersion` for the monotonically increasing build number.

Do not reuse a previously distributed build number.

## Change discipline

- Preserve bundled renderer resources and the embedded showcase when editing
  packaging scripts.
- Avoid adding network dependencies to Markdown rendering.
- Do not weaken Hardened Runtime or Gatekeeper compatibility to work around a
  signing problem.
- Do not commit generated `.app`, notarization archives, release ZIPs, signing
  material, or credentials unless the user explicitly requests artifact
  versioning.
