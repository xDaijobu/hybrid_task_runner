---
name: android_exact_alarm_permission
description: Guidance on handling Android 14+ exact alarm permission in Flutter projects using HybridTaskRunner.
---

# Android Exact Alarm Permission Skill

## Overview
This skill documents how to:
- Remove the deprecated `USE_EXACT_ALARM` permission.
- Use `permission_handler` to check and request `SCHEDULE_EXACT_ALARM`.
- Update `HybridRunner` with `canScheduleExactAlarms()` and `openExactAlarmSettings()`.
- Add UI flow in the example app.

## Steps
1. **Manifest** – Remove `<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>` from both package and example manifests.
2. **Dependency** – Add `permission_handler` to `pubspec.yaml`.
3. **HybridRunner API** – Implement static methods:
   ```dart
   static Future<bool> canScheduleExactAlarms() async {
     final status = await Permission.scheduleExactAlarm.status;
     return status.isGranted;
   }

   static Future<void> openExactAlarmSettings() async {
     await Permission.scheduleExactAlarm.request();
   }
   ```
4. **Example UI** – Add a permission status card and a dialog that calls `openExactAlarmSettings()`.
5. **README** – Document the new permission flow with screenshots and a compatibility table.
6. **Testing** – Verify on Android 14+ devices that the permission dialog appears and tasks schedule correctly.

## References
- Android 14 exact alarm changes: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms
- permission_handler package docs.
