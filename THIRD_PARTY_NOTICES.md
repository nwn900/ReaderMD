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

The Windows host also uses:

- WPF UI 4.3.0 — MIT License, copyright Leszek Pomianowski and WPF UI contributors

The Mermaid build bundles further components — DOMPurify, js-yaml, lodash-es and
cytoscape — whose notices Mermaid's own build embeds in `mermaid.min.js` and
which are also reproduced in the app.

## Where the notices actually ship

The renderer licenses require the copyright and license texts to travel with
every copy of the app, so they live in `Sources/ReaderMD/Acknowledgements.swift`
and are shown in full under **ReaderMD ▸ About ReaderMD** on macOS.

This file is the repository summary. It is copied into the macOS app's
`Contents/Resources/Legal` directory and into the Windows application output as
`THIRD_PARTY_NOTICES.md`, so the Windows package carries the WPF UI license.
The complete third-party license texts that satisfy the vendored renderer notice
requirements remain compiled into `Acknowledgements.swift`.

## WPF UI license

MIT License

Copyright (c) 2021-2025 Leszek Pomianowski and WPF UI Contributors. https://lepo.co/

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## When upgrading a vendored library

Update the version and license text in `Acknowledgements.swift` in the same
commit as the file in `Sources/ReaderMD/Resources/Renderer`, then this file.
`AcknowledgementsTests` reads the vendored bundles from disk and fails when a
declared version no longer matches the code actually being shipped.
