# Third-party notices

ReaderMD itself is available under the Apache License 2.0; see `LICENSE` and
`NOTICE`. This document covers software incorporated from other projects.

ReaderMD includes local browser distributions of the following open-source
projects, bundled so documents render without a network connection:

- markdown-it 14.3.0 — MIT License
- markdown-it-footnote 4.0.0 — MIT License
- Mermaid 11.16.0 — MIT License
- KaTeX 0.16.47 — MIT License (covers the library, stylesheet and web fonts)
- highlight.js 11.11.1 — BSD 3-Clause License

The Mermaid build bundles further components — DOMPurify, js-yaml, lodash-es and
cytoscape — whose notices Mermaid's own build embeds in `mermaid.min.js` and
which are also reproduced in the app.

## Where the notices actually ship

These licenses require the copyright and license texts to travel with every copy
of the app, so they live in `Sources/ReaderMD/Acknowledgements.swift` and are
shown in full under **ReaderMD ▸ About ReaderMD**.

This file is the repository summary and is also copied into the app's
`Contents/Resources/Legal` directory. The complete third-party license texts
that satisfy the renderer notice requirements remain compiled into
`Acknowledgements.swift`, so editing this summary alone is not enough.

## When upgrading a vendored library

Update the version and license text in `Acknowledgements.swift` in the same
commit as the file in `Sources/ReaderMD/Resources/Renderer`, then this file.
`AcknowledgementsTests` reads the vendored bundles from disk and fails when a
declared version no longer matches the code actually being shipped.
