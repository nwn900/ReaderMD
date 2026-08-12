# Bringing ReaderMD to another platform

Yes, this is encouraged.

The current product is deeply native to macOS, but its document renderer is
already a bundled web application with a narrow native bridge. A good port can
reuse behavior without pretending that AppKit is portable or reproducing macOS
chrome on another system.

## Start with an experiment

Before building a complete application:

1. open a **Platform port proposal** issue;
2. name the operating system, UI toolkit, embedded web view, and packaging
   approach;
3. render the bundled showcase completely offline;
4. open a local Markdown file and resolve a relative image;
5. prove one native bridge operation such as opening a link or copying code;
6. write down which contracts are genuinely portable and which are not.

That thin vertical slice is more useful than an abstract rewrite.

## The boundary today

The macOS application has three broad layers:

```text
Markdown and document state
          │
          ▼
Native bridge and platform adapters
          │
          ▼
Bundled HTML/CSS/JavaScript renderer
```

The renderer lives in `Sources/ReaderMD/Resources/Renderer/`. It accepts
document state from native code and emits narrow messages for user actions. It
does not fetch rendering dependencies from the network.

The current shell lives in `Sources/ReaderMD/` and uses AppKit, SwiftUI,
WebKit, PDFKit, Quick Look, and Uniform Type Identifiers. Those are macOS
adapters, not requirements for every future implementation.

Several files already contain mostly platform-neutral logic built on
Foundation, including document I/O, folder search, folder-workspace discovery,
external-change calculation, and parts of the model. Do not assume they can be
copied unchanged to every Swift platform; extract them only when a real port
demonstrates the correct interface.

## Behaviors a port should preserve

- clean launch opens an empty state;
- documents remain local files and open immediately;
- rendering works offline with pinned resources;
- relative links and local images resolve against the document;
- tables, diagrams, math, and highlighted code remain available offline;
- multiple files can stay open without unnecessary windows;
- closing the final document returns to the empty state;
- reading width remains continuously adjustable;
- focus mode removes chrome without destroying document state;
- untrusted links and content do not bypass the platform security model;
- the UI feels native to its host platform.

Quick Look, Apple code signing, the unified macOS toolbar, and Universal 2 are
macOS-specific. A Windows or Linux port should replace them with the closest
useful native integration, not emulate them blindly.

## A likely portable contract

An eventual shared contract will probably need operations in these groups:

- load and update Markdown plus appearance state;
- report outline and selection changes;
- open local and external links safely;
- route local image access through the host sandbox;
- copy plain, rich, and image content through the native clipboard;
- export or print using platform capabilities;
- report renderer errors without leaking document content.

Treat this as a hypothesis. Prefer extracting a contract from two working
implementations over designing one for imagined platforms.

## Choosing a stack

No cross-platform toolkit is prescribed. A port proposal should explain:

- how it delivers a platform-native experience;
- how it embeds and isolates the renderer;
- how local file permissions and links are handled;
- how offline assets are packaged and verified;
- how builds, updates, and signatures work;
- who intends to maintain it.

Using Swift is optional. Preserving the document experience is more important
than sharing a language.

## Tests before branding

Before an official port release, expect shared fixtures for renderer output,
unsafe URL handling, relative resources, large tables, diagrams, math, code,
clipboard behavior, and document restoration. Platform-specific accessibility,
installer, sandbox, and update tests are equally important.

Prototype names should make their experimental status clear. Coordinate with
the maintainer before distributing a build under the ReaderMD name or icon;
see [the trademark policy](../TRADEMARKS.md).
