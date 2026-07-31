# PreviewMD

A native macOS Markdown reader with a print-inspired preview, editing, tabs, outline navigation, search, and PDF export.

## Highlights

- GitHub Flavored Markdown, tables, task lists, alerts, and footnotes
- Direct rich-text editing in the rendered document
- A contextual selection toolbar for text, links, images, tables, code, diagrams, and math
- A left-margin `+` menu on empty lines for inserting every supported Markdown block
- Mermaid diagrams and charts
- KaTeX inline and display math
- Syntax highlighting with copy buttons
- Preview, source, and live split modes
- A focus mode that strips every control except the page and the width ruler
- Tabs, recent files, pinning, drag and drop, local images and relative links
- A live 560–1600 px reading-width ruler with a one-click table/data layout
- Modern, Classic, and Editorial reading styles with offline system typography
- Native macOS sidebar, toolbar, menus, keyboard shortcuts, and dark mode
- Narrow, comfortable, wide, and table presets, plus optional paper canvas
- Fully offline rendering

## Run

```bash
swift run PreviewMD
```

## Build a macOS app bundle

```bash
./scripts/build-app.sh
open dist/PreviewMD.app
```

The project targets macOS 14 or newer and builds a Universal 2 application for
Apple Silicon and Intel with Swift Package Manager.

## Create a signed and notarized release

The release script expects the `Developer ID Application: Astrography Sp. z
o.o. (4NZF9USX28)` signing identity and a `PreviewMD-Notary` keychain profile.
Create the profile once:

```bash
xcrun notarytool store-credentials "PreviewMD-Notary" \
  --apple-id "YOUR_APPLE_ACCOUNT_EMAIL" \
  --team-id "4NZF9USX28"
```

Use an app-specific password when prompted. Then build, sign, notarize, staple,
verify, and package the release:

```bash
./scripts/release-app.sh
```

The distributable ZIP is written to `dist/`.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| New Markdown | `⌘N` |
| Open Markdown | `⌘O` |
| Save | `⌘S` |
| Save As | `⌘⇧S` |
| Undo / redo | `⌘Z` / `⌘⇧Z` |
| Bold / italic / link | `⌘B` / `⌘I` / `⌘K` |
| Find in preview | `⌘F` |
| Export PDF | `⌘⇧E` |
| Focus mode | `⌘⇧F` |
| Toggle outline | `⌘⌥I` |
| Close tab | `⌘W` |
| Actual size | `⌘0` |
| Zoom in/out | `⌘+` / `⌘-` |

## Third-party rendering libraries

PreviewMD vendors pinned browser distributions of Markdown-it, markdown-it-footnote, Mermaid, KaTeX, and Highlight.js. They are bundled as local resources so document rendering does not require an internet connection.
