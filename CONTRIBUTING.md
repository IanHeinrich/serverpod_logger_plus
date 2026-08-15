# Contributing to serverpod_logger_plus

Thanks for helping out. This covers getting the project running locally,
what a change needs to pass before it merges, and how releases work.

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

Write clear, descriptive commit messages - there's no required prefix or
format. Squash-merge PRs down to one or a few meaningful commits.

## Pull requests

1. Branch from `main`.
2. Make your change with tests and docs.
3. Ensure the local checks above pass.
4. Fill in the pull request template.
5. Open the PR against `main`; CI must be green before merge.

**Don't bump `version:` in `pubspec.yaml`** unless you mean to trigger a
release - see below. That's usually left to a maintainer, in its own PR.

## Releases (maintainers)

A release is just an ordinary PR that:

1. Bumps `version:` in `pubspec.yaml`.
2. Adds a matching entry at the top of `CHANGELOG.md`.

Once that PR merges into `main`, `.github/workflows/ci.yml` notices the new
version has no matching `vX.Y.Z` git tag yet, and:

1. Creates that tag and a GitHub release (release notes auto-generated from
   merged PRs since the last tag).
2. Publishes the new version to pub.dev via OIDC - no stored tokens or
   secrets, since release and publish both run as jobs in that same workflow
   run (a tag pushed by the default `GITHUB_TOKEN` can't trigger a *separate*
   workflow, so publishing happens right there instead of waiting on one).

If a push to `main` doesn't change `version:`, none of this runs - only the
`test` job does.

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

After that, the flow above takes over for every future release.
