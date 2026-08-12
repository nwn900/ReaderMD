# ReaderMD governance

ReaderMD uses a founder-led, contribution-friendly governance model. The goal
is to make decisions clearly and in public while the project is small, then add
structure only when the community needs it.

## Stewardship

[Adam Jesionkiewicz](AUTHORS.md) is the founder, original author, lead
maintainer, and current project steward. Adam has final responsibility for:

- the product direction and design language;
- the official repository and release channels;
- accepting and reverting changes;
- appointing maintainers;
- the ReaderMD name, icon, and visual identity;
- deciding which builds and ports are official project releases.

ReaderMD is Adam's independent personal project. No company owns or governs
the project. A company or service used to sign, host, mirror, sponsor, or
distribute a build does not gain project authority or intellectual-property
rights by doing so.

## How decisions are made

Routine changes are decided through issue and pull-request discussion. The lead
maintainer weighs:

- benefit to readers and writers;
- consistency with the product principles in `AGENTS.md`;
- accessibility, privacy, security, and offline behavior;
- long-term maintenance cost;
- quality of evidence and tests;
- whether the change creates a useful cross-platform boundary.

For substantial architecture or product changes, the maintainer may request a
short design note in the issue before implementation. Decisions should include
the reasoning, especially when a popular proposal is declined.

Consensus is preferred. When consensus does not emerge, the lead maintainer
makes the call so the project can continue moving. A declined proposal may be
revisited when constraints or evidence change.

## Roles

### Contributor

Anyone who improves the project through code, design, documentation, testing,
triage, research, or community work.

### Reviewer

A trusted contributor who regularly reviews work in an area they understand.
Reviewers may approve changes but do not automatically have merge access.

### Maintainer

A trusted contributor with responsibility for an area of the project and, when
appropriate, repository permissions. Maintainers are expected to review,
communicate decisions, protect project invariants, and help other contributors
succeed.

Maintainers are appointed by the lead maintainer based on sustained judgment,
care, reliability, and community conduct — not commit count alone. Roles can be
reduced after prolonged inactivity or removed for loss of trust, with a private
conversation whenever feasible.

## Releases

Official releases are approved by the lead maintainer and published through
channels linked from the official repository. Signing infrastructure may be
operated by a third-party distributor, but release authority stays with the
project steward.

Community builds and forks are welcome under Apache-2.0. They must not imply
official status and must follow `TRADEMARKS.md`.

## Changes to governance

This document can evolve through a public pull request. Governance should become
more distributed as a durable maintainer community emerges, but ownership of
the founder's name and project trademarks does not transfer implicitly with a
role or repository permission.
