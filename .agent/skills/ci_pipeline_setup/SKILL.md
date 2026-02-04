---
name: ci_pipeline_setup
description: Sets up a GitHub Actions CI pipeline for Flutter projects.
---

# CI Pipeline Setup Skill

## Overview
Provides a ready‑to‑use GitHub Actions workflow that runs static analysis, unit tests, and optionally publishes the package when a tag is pushed.

## Workflow file (`.github/workflows/ci.yml`)
```yaml
name: CI

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - name: Install dependencies
        run: flutter pub get
      - name: Analyze
        run: flutter analyze
      - name: Run tests
        run: flutter test
      - name: Generate release notes (optional)
        if: startsWith(github.ref, 'refs/tags/')
        run: |
          dart run tool/generate_release_notes.dart
      - name: Publish to pub.dev (optional)
        if: startsWith(github.ref, 'refs/tags/')
        env:
          PUB_DEV_TOKEN: ${{ secrets.PUB_DEV_TOKEN }}
        run: |
          dart pub publish --force
```

## How to add it
1. Create the file at `.github/workflows/ci.yml` in the repository.
2. Ensure the `tool/generate_release_notes.dart` script exists (see `release_notes_generator` skill).
3. Add a secret `PUB_DEV_TOKEN` in the repo settings if you want automatic publishing.

## Customisation
- Change the Flutter channel (`stable`, `beta`, `master`).
- Add additional steps such as `flutter build apk` for CI artifacts.
- Enable matrix builds for multiple OSes.

---
