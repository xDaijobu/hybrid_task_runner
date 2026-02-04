---
name: android_manifest_validator
description: Checks AndroidManifest.xml for required permissions, minSdk, and policy compliance.
---

# Android Manifest Validator Skill

## Overview
This skill provides a small Dart/CLI script that validates the Android `AndroidManifest.xml` for:
- Presence/absence of `USE_EXACT_ALARM` (must be removed).
- Presence of `SCHEDULE_EXACT_ALARM`.
- `minSdkVersion` >= 21.
- Any duplicate permission entries.
- Optional check for `android:exported` on components for API 31+.

## Usage
1. Save the script as `tool/validate_manifest.dart` inside the repo.
2. Run:
   ```bash
   dart run tool/validate_manifest.dart path/to/AndroidManifest.xml
   ```
3. The script prints warnings/errors and exits with non‑zero code on failures.

## Script (excerpt)
```dart
import 'dart:io';
import 'package:xml/xml.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run validate_manifest.dart <manifest_path>');
    exit(1);
  }
  final file = File(args[0]);
  final content = file.readAsStringSync();
  final document = XmlDocument.parse(content);
  final manifest = document.rootElement;
  final uses = manifest.findAllElements('uses-permission');
  bool hasExactAlarm = false;
  bool hasScheduleExact = false;
  for (var u in uses) {
    final name = u.getAttribute('android:name');
    if (name == 'android.permission.USE_EXACT_ALARM') hasExactAlarm = true;
    if (name == 'android.permission.SCHEDULE_EXACT_ALARM') hasScheduleExact = true;
  }
  if (hasExactAlarm) {
    print('[ERROR] USE_EXACT_ALARM permission should be removed.');
    exit(2);
  }
  if (!hasScheduleExact) {
    print('[ERROR] SCHEDULE_EXACT_ALARM permission is missing.');
    exit(3);
  }
  // Additional checks can be added here.
  print('✅ Manifest validation passed.');
}
```

## Integration
Add a step in your CI workflow (see `ci_pipeline_setup` skill) to run this validator on both the package and example manifests.

---
