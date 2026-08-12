# Publication audit

Date: 2026-08-12

## Executive summary

The repository and all reachable Git history were reviewed before the
open-source preparation. No credentials, private keys, Apple signing material,
subscriber databases, or known-format service tokens were found. The repository
was published at <https://github.com/ashtree74/PreviewMD> under Adam
Jesionkiewicz's personal GitHub account and is identified by GitHub as
Apache-2.0 licensed.

No critical, high, or medium publication blockers were identified. Rewriting
Git history is not recommended on the present evidence. Post-publication
verification completed successfully.

## Scope

The review covered:

- tracked and ignored files in the working tree;
- names and sizes of blobs reachable from Git refs;
- all commit author metadata and commit messages;
- repository history for sensitive filenames and known secret formats;
- absolute development and deployment paths;
- signing, notarization, deployment, and mailing-list configuration;
- browser JavaScript security-sensitive sinks and the landing-page CSP;
- vendored library inventory and shipped third-party notices.

Pattern scans included AWS credentials, GitHub tokens, Slack tokens, live
Stripe keys, private-key headers, password and credential assignments, database
files, certificate containers, mobile provisioning profiles, and common secret
filenames. A second history scan was run with `git-secrets` and custom token
patterns.

## Findings

### PUB-001 — Historical release binaries increase clone size

**Severity:** Low

**Location:** Git history; historical `site/PreviewMD-*-macOS.dmg` and
`site/PreviewMD-*-macOS.zip` blobs

**Evidence:** reachable release artifacts range from approximately 3.5 MB to
7.2 MB each. The current landing page intentionally serves one current DMG.

**Impact:** fresh clones transfer more data than a source-only repository, and
the cost grows if every future release is committed.

**Fix/decision:** do not rewrite history before publication. The history is
short, single-author, and otherwise clean; changing every commit ID creates more
risk than the current size justifies. Keep the current artifact required by the
landing site, but adopt an explicit artifact-retention policy before adding
more releases to normal Git history.

**Mitigation:** publish archival binaries through GitHub Releases or another
documented artifact channel when the landing-site deployment no longer needs a
tracked copy.

**False-positive notes:** these are public application builds, not secrets or
private user data.

### PUB-002 — Public operational metadata exists

**Severity:** Informational

**Location:** `deploy/README.md:3`, `deploy/README.md:13`,
`scripts/release-app.sh:7`, and `scripts/release-app.sh:8`; similar historical
values exist in earlier commits.

**Evidence:** the repository names the public landing-page hostname, a local
SSH alias, conventional server paths, the Apple Developer identity, and the
name of a local Keychain profile. No credential corresponding to any of these
identifiers was found.

**Impact:** the values reveal limited deployment topology but do not grant
access.

**Fix/decision:** keep metadata needed to reproduce current release and deploy
procedures; remove obsolete identifiers when they no longer serve that goal.

**Mitigation:** treat hostnames, team IDs, profile names, and submission IDs as
public metadata, never as authentication; keep actual credentials only in
Keychain or repository-secret storage.

**False-positive notes:** an Apple Team ID and a Keychain profile name are
identifiers, not signing keys or notarization credentials.

### PUB-003 — Author identity is intentionally public

**Severity:** Informational

**Location:** Git author metadata, `AUTHORS.md:5`, and `CITATION.cff:5`

**Evidence:** the history and project metadata contain Adam Jesionkiewicz's
name and `adam@jesion.pl`; all 60 commits reachable during the audit had the
same author identity.

**Impact:** the maintainer's chosen public identity is visible in every clone.

**Fix/decision:** retain it as deliberate authorship and contact attribution.

**Mitigation:** use a dedicated public project address in future if the current
address should no longer be public.

**False-positive notes:** this is intentional attribution, not an accidental
personal-data leak.

### WEB-001 — Landing page executes third-party analytics JavaScript

**Severity:** Low

**Location:** `site/index.html:22` and `deploy/nginx-previewmd.conf:78`

**Evidence:** the landing page loads Google Analytics from an origin explicitly
allowed by the production Content Security Policy.

**Impact:** third-party JavaScript executes in the page and creates privacy and
supply-chain exposure beyond the self-hosted application.

**Fix/decision:** retain the existing analytics integration for now; this audit
does not silently change product analytics behavior.

**Mitigation:** keep the CSP allowlist narrow, document privacy behavior
accurately, and periodically reconsider whether the local aggregate download
counter is sufficient.

**False-positive notes:** a strict CSP reduces exposure but does not make a
changing third-party script equivalent to locally pinned code; practical SRI
pinning is not available for the dynamically served analytics script.

## Existing safeguards

- subscriber data lives outside the public `site/` directory;
- the data directory and common credential formats are ignored by Git;
- release secrets are expected only in the macOS Keychain;
- Markdown raw HTML is disabled and diagram rendering uses strict security mode;
- the landing page has no inline script or style and production nginx supplies
  a restrictive CSP;
- third-party licenses are compiled into the application and checked by tests.

## Completed locally

- [x] scan all reachable Git refs with `git-secrets` and custom known-token
  patterns;
- [x] scan the final working tree, including untracked publication files;
- [x] confirm no subscriber database, `.env`, signing key, or credential file
  is tracked or waiting to be published;
- [x] review the final working-tree diff;
- [x] confirm Actions workflows use read-only default permissions;
- [x] run the Swift, Quick Look, and landing-page test suites;
- [x] build both application executables as Universal 2;
- [x] verify the assembled app's signature and bundled legal files;
- [x] validate GitHub workflow, issue-form, Dependabot, and citation YAML;
- [x] resolve every local Markdown link in the project documentation.

## Publication verification

- [x] publish the repository from Adam Jesionkiewicz's personal GitHub account;
- [x] expose the project under the Apache-2.0 license while documenting
  Astrography Sp. z o.o. only as a macOS signing and distribution provider;
- [x] enable GitHub secret scanning and push protection;
- [x] enable private vulnerability reporting;
- [x] protect `main` with required pull requests, CI, and DCO checks;
- [x] require CODEOWNERS review, with a PR-only founder bypass to prevent a
  single-maintainer lockout;
- [x] enable GitHub Discussions, because the community links point there;
- [x] confirm the public download points to the intended notarized release;
- [x] make an anonymous fresh clone and inspect it from an outsider's
  perspective.

The final GitHub API verification reported public visibility, owner
`ashtree74`, Apache-2.0, Discussions enabled, secret scanning enabled, push
protection enabled, private vulnerability reporting enabled, read-only default
Actions permissions, and the active `Protect main` ruleset. The secret-scanning
alert endpoint returned zero alerts.

The hosted `PreviewMD-1.7-11-macOS.dmg` was byte-identical to the audited file
at SHA-256
`4291f8e7a13af647e8f864b780d49b51d79f01097575992573f191d288fa4641`.
Its code signature was valid, its stapled notarization ticket validated, and
Gatekeeper accepted it as `Notarized Developer ID`.

An unauthenticated shallow clone with credential helpers and GitHub tokens
disabled resolved `main` to `c1b3faf91fc7972a2f9fd80fdb708e1c808d5570`.
From that clone, all 135 XCTest tests, all 5 Swift Testing tests, all 9 landing
page tests, shell syntax checks, and property-list validations passed. The
post-merge GitHub Actions run for the same commit also passed.

## When history rewriting would become necessary

Rewrite only if a secret, private document, subscriber database, signing key, or
other material that must not remain downloadable is found. First revoke or
rotate the credential; rewriting history does not make a leaked secret safe.
Then coordinate the rewrite, remove affected remote refs and cached artifacts,
force-push once, and require every existing clone to rebase or clone again.

Large public binaries alone are normally a repository-hygiene issue, not a
reason for an emergency security rewrite.

## Limitations

Pattern-based scans cannot prove the absence of every possible secret. Vendored
minified libraries were excluded from generic keyword review after their
versions and provenance were checked, because they contain many token-like
strings. The Swift application did not receive a complete vulnerability audit
as part of this publication review. Security-sensitive changes should continue
to receive targeted review and regression tests.
