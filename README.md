# ReaderMD

ReaderMD is a native, offline-first Markdown reader and editor for Windows and macOS. It keeps documents as local files and uses a bundled renderer for Markdown, tables, math, diagrams, syntax highlighting, and rich editing.

## Windows

The Windows app uses WPF and Microsoft Edge WebView2. It reuses the same bundled renderer as the macOS app and maps local document folders into the web view without network access.

Windows features include:

- Document, split, and source views.
- Direct editing in the rendered document.
- Multiple open documents with tabs.
- Folder browsing and drag-and-drop opening.
- Local images and relative links.
- Search and document outline navigation.
- Adjustable reading width and theme controls.
- Focus mode.
- Native save and save-as flows.
- PDF export and Windows printing.
- Rich and plain clipboard copy.
- Offline math, diagrams, and syntax highlighting.

### Build on Windows

Install the .NET 8 SDK and the Microsoft Edge WebView2 Runtime.

```powershell
git clone https://github.com/nwn900/ReaderMD.git
cd ReaderMD
dotnet build Windows/ReaderMD.Windows/ReaderMD.Windows.csproj -c Release
dotnet run --project Windows/ReaderMD.Windows/ReaderMD.Windows.csproj
```

The project uses `Microsoft.Web.WebView2` version `1.0.4078.44`.

## macOS

The original Swift application remains in `Sources/ReaderMD/`. It uses SwiftUI, AppKit, WebKit, PDFKit, and native macOS document integrations.

```bash
swift run ReaderMD
```

Run the Swift tests with:

```bash
swift test
```

## Renderer

The renderer is in `Sources/ReaderMD/Resources/Renderer/`. It ships with pinned local dependencies and does not require a rendering service.

The native hosts send document state to the renderer and receive narrow bridge messages for actions such as editing and clipboard operations. Windows uses a WebView2 bridge. macOS uses a WebKit bridge.

## Repository layout

```text
Windows/ReaderMD.Windows/      Windows WPF application
Sources/ReaderMD/              macOS application and shared renderer
Sources/ReaderMDQuickLook/     macOS Finder extension
Tests/ReaderMDTests/           Swift behavior and regression tests
scripts/                       macOS build and release tooling
site/                          Project site
```

## License

ReaderMD is licensed under the Apache License 2.0. See `LICENSE` and `THIRD_PARTY_NOTICES.md` for details.
