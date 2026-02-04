---
name: flutter-background-tasks
description: Patterns for implementing background task execution in Flutter using AlarmManager, WorkManager, and isolate callback handling
---

# Flutter Background Tasks Skill

## Overview

This skill documents patterns for implementing reliable background task execution in Flutter, particularly focusing on Android. It covers three key plugins and their integration patterns.

---

## Core Concepts

### Isolates in Flutter

Dart isolates are independent execution threads that **do not share memory**. When background tasks run (via AlarmManager or WorkManager), they execute in separate isolates from the main UI.

**Implications:**
- Cannot directly access main app state
- Cannot use instance methods as callbacks
- Must use top-level or static functions
- Must use `PluginUtilities` to pass function references

---

## Plugin: android_alarm_manager_plus

**Purpose:** Schedule precise alarms that wake the device and execute Dart code.

### Setup

```yaml
# pubspec.yaml
dependencies:
  android_alarm_manager_plus: ^4.0.6
```

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>

<service
    android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmService"
    android:permission="android.permission.BIND_JOB_SERVICE"
    android:exported="false"/>
<receiver
    android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmBroadcastReceiver"
    android:exported="false"/>
<receiver
    android:name="dev.fluttercommunity.plus.androidalarmmanager.RebootBroadcastReceiver"
    android:enabled="false"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
    </intent-filter>
</receiver>
```

### Callback Pattern

```dart
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

// MUST be top-level or static
// MUST have this annotation for release builds
@pragma('vm:entry-point')
void alarmCallback() {
  print('Alarm fired!');
  // Keep this short - you have ~10 seconds
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  runApp(MyApp());
}

// Schedule a one-shot alarm
await AndroidAlarmManager.oneShot(
  const Duration(minutes: 5),
  0, // Alarm ID
  alarmCallback,
  exact: true,
  wakeup: true,
  alarmClock: true,
);

// Schedule a periodic alarm
await AndroidAlarmManager.periodic(
  const Duration(hours: 1),
  1, // Alarm ID
  alarmCallback,
  exact: true,
  wakeup: true,
);
```

### Key Parameters

| Parameter | Description |
|-----------|-------------|
| `exact` | Use exact timing (requires SCHEDULE_EXACT_ALARM permission on Android 12+) |
| `wakeup` | Wake device from sleep |
| `alarmClock` | Use `setAlarmClock` for highest priority |
| `rescheduleOnReboot` | Re-schedule after device reboot |

### Limitations

- **Short execution window:** ~10 seconds max
- **Doze mode:** May be delayed unless using `alarmClock: true`
- **Battery optimization:** User may need to disable for your app

---

## Plugin: workmanager

**Purpose:** Execute deferrable, guaranteed background work with longer execution windows.

### Setup

```yaml
# pubspec.yaml
dependencies:
  workmanager: ^0.5.2
```

```xml
<!-- AndroidManifest.xml (handled by plugin, but good to know) -->
<!-- WorkManager uses JobScheduler internally -->
```

### Callback Pattern

```dart
import 'package:workmanager/workmanager.dart';

// MUST be top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'simpleTask':
        print('Running simple task');
        break;
      case 'heavyTask':
        // Can run for ~10+ minutes
        await doHeavyWork();
        break;
    }
    return Future.value(true); // Return false to retry
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  runApp(MyApp());
}

// Register a one-off task
await Workmanager().registerOneOffTask(
  'uniqueTaskId',
  'heavyTask',
  inputData: {'key': 'value'},
  constraints: Constraints(
    networkType: NetworkType.connected,
    requiresBatteryNotLow: true,
  ),
);

// Register a periodic task
await Workmanager().registerPeriodicTask(
  'periodicTaskId',
  'syncTask',
  frequency: Duration(hours: 1),
);
```

### Key Features

- **Guaranteed execution:** Will run eventually, even after reboot
- **Constraints:** Network, battery, charging, storage conditions
- **Backoff policy:** Retry with exponential delay on failure
- **Input data:** Pass data to the background task

### Limitations

- **Minimum periodic interval:** 15 minutes on Android
- **Not precise:** May be delayed by system optimization
- **Cannot wake at exact times:** Use with AlarmManager for precision

---

## PluginUtilities: Callback Handle Pattern

**Purpose:** Pass function references between isolates.

### The Problem

You cannot pass a function directly to a background isolate because isolates don't share memory.

### The Solution

Use `PluginUtilities` to convert a function to a handle (integer), persist it, and retrieve it in the background isolate.

```dart
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The user's heavy task - MUST be top-level or static
@pragma('vm:entry-point')
Future<bool> myHeavyTask() async {
  await Future.delayed(Duration(minutes: 2));
  print('Heavy task completed!');
  return true;
}

// Store the callback handle
Future<void> storeCallback(Future<bool> Function() callback) async {
  final handle = PluginUtilities.getCallbackHandle(callback);
  if (handle == null) {
    throw Exception('Callback must be a top-level or static function');
  }
  
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('callback_handle', handle.toRawHandle());
}

// Retrieve and execute in background isolate
Future<void> executeStoredCallback() async {
  final prefs = await SharedPreferences.getInstance();
  final rawHandle = prefs.getInt('callback_handle');
  
  if (rawHandle != null) {
    final handle = CallbackHandle.fromRawHandle(rawHandle);
    final callback = PluginUtilities.getCallbackFromHandle(handle);
    
    if (callback != null) {
      // Must cast to the expected function type
      final typedCallback = callback as Future<bool> Function();
      await typedCallback();
    }
  }
}
```

### Validation

Always validate callbacks before storing:

```dart
bool isValidCallback(Function callback) {
  final handle = PluginUtilities.getCallbackHandle(callback);
  return handle != null;
}
```

---

## Hybrid Strategy Pattern

**Use Case:** Need precise timing AND long execution windows.

### Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  AlarmManager   │───▶│   WorkManager    │───▶│  AlarmManager    │
│   (Scheduler)   │    │   (Executor)     │    │  (Reschedule)    │
│                 │    │                  │    │                  │
│  • Wakes device │    │  • Runs task     │    │  • Next trigger  │
│  • Exact timing │    │  • 10+ min exec  │    │  • Exact timing  │
│  • ~10s window  │    │  • Guaranteed    │    │                  │
└─────────────────┘    └──────────────────┘    └──────────────────┘
```

### Implementation Pattern

```dart
// 1. Alarm fires -> enqueue WorkManager task
@pragma('vm:entry-point')
void alarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Workmanager().registerOneOffTask(
    'hybrid_task_${DateTime.now().millisecondsSinceEpoch}',
    'hybridTask',
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

// 2. WorkManager executes task -> reschedule alarm
@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'hybridTask') {
      // Execute the user's heavy task
      await executeStoredCallback();
      
      // Reschedule the next alarm
      final interval = await getStoredInterval();
      await AndroidAlarmManager.oneShot(
        interval,
        0,
        alarmCallback,
        exact: true,
        wakeup: true,
      );
    }
    return true;
  });
}
```

---

## Best Practices

### 1. Always Use @pragma Annotation

```dart
@pragma('vm:entry-point')
void myCallback() { ... }
```

Without this, the callback may be tree-shaken in release builds.

### 2. Initialize Plugins in Background Isolates

```dart
@pragma('vm:entry-point')
void backgroundCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Now plugins are available
}
```

### 3. Handle Android 12+ Exact Alarm Permission

```dart
// Check if exact alarms are allowed (Android 12+)
if (Platform.isAndroid) {
  // Consider using permission_handler package
  // to request SCHEDULE_EXACT_ALARM
}
```

### 4. Logging in Background Isolates

```dart
import 'dart:developer' as developer;

@pragma('vm:entry-point')
void backgroundCallback() {
  developer.log('Background task running', name: 'MyApp');
  // Also visible in logcat with proper tag
}
```

### 5. Error Handling

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await runTask();
      return true;
    } catch (e, stackTrace) {
      developer.log('Task failed: $e', error: e, stackTrace: stackTrace);
      return false; // WorkManager will retry with backoff
    }
  });
}
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Callback returns null from `getCallbackHandle` | Ensure function is top-level or static |
| Task doesn't run in release mode | Add `@pragma('vm:entry-point')` |
| Alarm delayed significantly | Check Doze mode, use `alarmClock: true` |
| WorkManager task not triggered | Check constraints, may be deferred |
| SharedPreferences not available | Call `WidgetsFlutterBinding.ensureInitialized()` |
