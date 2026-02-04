---
name: documentation_generator
description: Generates API documentation for the Flutter package using dartdoc and integrates it into CI.
---

# Documentation Generator Skill

## Overview
Provides a script and CI step to automatically generate HTML API docs with `dartdoc` and publish them (e.g., to GitHub Pages).

## Script (`tool/generate_docs.dart`)
```dart
import 'dart:io';

Future<void> main() async {
  final result = await Process.run('flutter', ['pub', 'global', 'activate', 'dartdoc']);
  if (result.exitCode != 0) {
    print('Failed to activate dartdoc: ${result.stderr}');
    exit(1);
  }
  final gen = await Process.run('flutter', ['pub', 'global', 'run', 'dartdoc']);
  if (gen.exitCode != 0) {
    print('dartdoc failed: ${gen.stderr}');
    exit(1);
  }
  print('Documentation generated in doc/api');
}
```
Run with:
```bash
dart run tool/generate_docs.dart
```
The output is placed in `doc/api`.

## CI Integration (add to `ci_pipeline_setup` workflow)
```yaml
- name: Generate docs
  run: dart run tool/generate_docs.dart
- name: Deploy to GitHub Pages
  if: github.ref == 'refs/heads/main'
  uses: peaceiris/actions-gh-pages@v3
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_dir: doc/api
```

## Customisation
- Change the output directory via `--output` flag in `dartdoc`.
- Use `dartdoc --exclude` to omit internal packages.
- Add a `doc` folder to the repo and commit the generated HTML for versioned docs.

---
