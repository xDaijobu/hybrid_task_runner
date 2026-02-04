---
name: release_notes_generator
description: Generates changelog entries from commit messages and provides a template for release notes.
---

# Release Notes Generator Skill

## Overview
A small Dart script that reads Git commit logs since the last tag and produces a formatted markdown section for `CHANGELOG.md`.

## How it works
1. Find the latest tag: `git describe --tags --abbrev=0`.
2. Get commits after that tag: `git log <last-tag>..HEAD --pretty=format:"%h %s"`.
3. Group commits by conventional‑commit prefixes (`feat:`, `fix:`, `docs:`, etc.).
4. Output a markdown block like:
```markdown
## [X.Y.Z] - YYYY‑MM‑DD

### Added
- Feature description

### Fixed
- Bug description
```

## Usage
Save the script as `tool/generate_release_notes.dart` and run:
```bash
dart run tool/generate_release_notes.dart
```
It will append the new section to `CHANGELOG.md` and open the file for review.

## Integration
Add a step in the CI pipeline (see `ci_pipeline_setup` skill) to automatically generate a draft release note on every push to `main`.
