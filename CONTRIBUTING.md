# Contributing to serverpod_logger_plus

Thanks for your interest in improving `serverpod_logger_plus`! This document
covers setting up the project, the checks your change needs to pass, and how
releases work.

## Prerequisites

- Dart SDK `^3.6.0` (check with `dart --version`).
- No database or Docker is required for the package's own test suite.

## Getting started

```bash
git clone https://github.com/ianheinrich/serverpod_logger_plus.git
cd serverpod_logger_plus
dart pub get
```

## Local checks

Before opening a pull request, run the same checks CI runs (see
`.github/workflows/ci.yml`):

```bash
dart format .                 # formatting (CI fails on any diff)
dart analyze --fatal-infos    # static analysis
dart test                     # unit tests
dart pub publish --dry-run    # packaging sanity check
```

All four must pass. CI runs them on every pull request and push to `main`.

## Testing philosophy

- Prefer **behavioral, outside-in tests** that drive the public API over tests
  of private helpers.
- The structured writers are tested by capturing `print` output in a `Zone`
  (see `test/util/capture_print.dart`) and asserting on the decoded JSON.
- The end-to-end Y-Splitter behavior (routing through a real `Session`) is
  covered by a `withServerpod` integration test that lives inside a generated
  Serverpod server, not in this package - see the **Testing** section of the
  README for the copy-paste pattern.

## Coding conventions

- Write self-documenting code: prefer clear names over comments. Add a comment
  only when it captures *why* something is done (a gotcha or deliberate
  tradeoff), not *what* the code does.
- Keep each `LogWriter` a flat, self-contained schema that can be read against
  its provider's documentation.
- Match the formatting produced by `dart format`.

## Commit messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/).
The commit type drives automated versioning and the changelog:

- `feat:` - a new feature (triggers a release)
- `fix:` - a bug fix (triggers a release)
- `docs:`, `test:`, `refactor:`, `chore:`, `ci:` - no release on their own
- `feat!:` / `fix!:`, or a `BREAKING CHANGE:` footer - a breaking change

Example: `feat: add Grafana Loki log writer`.

While the package is pre-1.0, breaking changes bump the minor version and
features bump the patch version.

## Pull requests

1. Branch from `main`.
2. Make your change with tests and docs.
3. Ensure the local checks above pass.
4. Fill in the pull request template.
5. Open the PR against `main`; CI must be green before merge.

You do not need to edit `CHANGELOG.md` or bump the version yourself - that is
automated (see below).

## Releases (maintainers)

Releases are automated with
[release-please](https://github.com/googleapis/release-please):

1. As Conventional-Commit PRs merge into `main`, release-please maintains a
   "release" PR that bumps `version:` in `pubspec.yaml` and updates
   `CHANGELOG.md`.
2. Merging that release PR creates a `vX.Y.Z` git tag and GitHub release.
3. The tag triggers `.github/workflows/publish.yml`, which publishes to pub.dev
   via OIDC (no stored tokens).

### One-time setup

Automated publishing can only be enabled once the package already exists on
pub.dev, so the very first release is manual:

1. `dart pub publish --dry-run` and resolve any warnings.
2. `dart pub login`, then `dart pub publish`. This always creates the package
   under your personal pub.dev account first - pub.dev has no way to publish
   directly under a publisher.
3. This package is published under the [heinrich.dev](https://pub.dev/publishers/heinrich.dev)
   verified publisher. On the package's pub.dev **Admin** tab, use
   **Publisher** to transfer it from your personal account to `heinrich.dev`.
4. On the same **Admin** tab, enable **Automated publishing** for GitHub
   Actions, pointing at this repository with the tag pattern `v{{version}}`.
   This works the same whether the package belongs to a publisher or a
   personal account.

Then add a repository secret named `RELEASE_PLEASE_TOKEN` - a fine-grained
personal access token with `contents: write` and `pull-requests: write` on
this repository. release-please uses it to push the release tag so that the tag
triggers the publish workflow (a tag pushed with the default `GITHUB_TOKEN`
would not).

After that, the release-please flow above takes over.
