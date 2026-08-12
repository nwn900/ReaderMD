# PreviewMD roadmap

This is a direction, not a promise or a queue. The best roadmap item is often a
small contribution that teaches the project something concrete.

## North star

Make Markdown feel like a durable document format everywhere: fast to open,
beautiful to read, safe to keep local, and pleasant to edit without losing the
plain-text source.

## Now: make the macOS foundation exceptional

- tighten accessibility, keyboard flow, and reduced-motion behavior;
- keep source, preview, selection, and scroll synchronization dependable;
- expand regression coverage with real-world Markdown fixtures;
- improve export fidelity and portable rich copy;
- keep Quick Look, folder workflows, and external-change handling robust;
- make release provenance and dependency upgrades easier to verify.

## Next: make the portable seams explicit

- separate renderer contracts from macOS window and file-system adapters;
- define fixtures that every platform must render consistently;
- document the native bridge as a small protocol instead of implicit calls;
- identify pure document/search logic that can become reusable modules;
- prototype a headless renderer harness for cross-platform tests.

## Explore: bring PreviewMD elsewhere

- a native Windows shell with system file, window, and print integration;
- a Linux desktop shell that respects the host environment;
- editor and file-manager integrations built from the shared renderer;
- community-defined workflows we have not imagined yet.

Ports should preserve the spirit, not clone macOS pixels. See
`docs/PORTING.md`.

## Things we protect while growing

- files remain ordinary files;
- rendering remains offline and deterministic;
- no account is required;
- documents are not telemetry;
- platform-native behavior matters;
- accessibility and security are product features;
- official releases remain clearly distinguishable from forks.
