# Security policy

PreviewMD opens documents that may come from untrusted sources. Security reports
are taken seriously, especially when they involve code execution, sandbox
escape, unintended file access, unsafe link handling, privacy, the Quick Look
extension, release integrity, or the landing-page subscriber database.

## Reporting a vulnerability

**Do not open a public issue for a vulnerability or include exploit details in
a public discussion.**

Use GitHub's private vulnerability reporting for this repository. If that is not
available, email [adam@jesion.pl](mailto:adam@jesion.pl) with the subject
`[PreviewMD security]`.

Please include, when possible:

- the affected version or commit;
- the operating system and hardware architecture;
- a minimal reproduction or proof of concept;
- the expected and observed behavior;
- the impact and any known preconditions;
- whether the report or reproduction contains private information.

Never send real credentials, personal documents, subscriber data, or production
private keys. Use synthetic test data.

You should receive an acknowledgement within seven days. Timing for a fix and
disclosure depends on severity, reproducibility, and maintainer availability.
Please allow a reasonable coordinated-disclosure period before publishing
details.

## Supported versions

Security fixes target the latest public release and the current `main` branch.
Older builds may receive a fix when the impact justifies it, but are not
guaranteed ongoing support.

## Scope notes

- Rendering is designed to work without network access.
- The main app and the Quick Look extension have different sandbox boundaries;
  a behavior that is safe in one may not be safe in the other.
- The website stores newsletter addresses and aggregate download counts in a
  database outside the public document root.
- Official macOS releases are signed and notarized. Build or release credentials
  do not belong in issues, pull requests, CI logs, or repository files.

## Research conduct

Good-faith testing against code and systems you are authorized to use is
welcome. Avoid privacy violations, persistence, service disruption, destructive
actions, and accessing data that is not yours. Stop and report if testing
unexpectedly exposes user or production data.
