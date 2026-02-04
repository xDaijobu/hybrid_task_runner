# Hybrid Task Runner

[![pub package](https://img.shields.io/pub/v/hybrid_task_runner.svg)](https://pub.dev/packages/hybrid_task_runner)

A Flutter package for running background tasks on Android. It combines AlarmManager + WorkManager to get the best of both worlds.

**Platform: Android only** (iOS is not supported yet)

## Why Was This Made?

Background execution on Android is complicated. There are two main options:

1. **AlarmManager** - High precision, can set exact times, but only runs for ~10 seconds
2. **WorkManager** - Can run for a long time (10+ minutes), but timing is not exact as it's batched by the system

This package combines both:
- AlarmManager triggers at the precise time
- Immediately enqueues a WorkManager task
- WorkManager runs the heavy task (can run 10+ minutes)
- After completion, schedules the next alarm

So you get timing precision AND long execution duration.

## Dependencies

```yaml
dependencies:
  android_alarm_manager_plus: ^4.0.0
  workmanager: ^0.9.0
  shared_preferences: ^2.0.0
```

**Why use these?**

| Package | Purpose |
|---------|---------|
| `android_alarm_manager_plus` | Set exact alarm, wake up device, survive reboot |
| `workmanager` | Execute long-running task, survive process death |
| `shared_preferences` | Store callback handle & config across isolates |

## Install

Run this command:

```bash
flutter pub add hybrid_task_runner
```

Or add it to `pubspec.yaml`:

```yaml
dependencies:
  hybrid_task_runner: ^1.1.0
```

## Android Setup

### 1. Edit `android/app/src/main/AndroidManifest.xml`

Add permissions inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

> **Note:** Do NOT add `USE_EXACT_ALARM` unless your app is a calendar or alarm clock app. That permission is restricted by Google Play policy.

Add service & receivers inside `<application>`:

```xml
<!-- AlarmManager -->
<service
    android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmService"
    android:permission="android.permission.BIND_JOB_SERVICE"
    android:exported="false"/>
<receiver
    android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmBroadcastReceiver"
    android:exported="false"/>
<receiver
    android:name="dev.fluttercommunity.plus.androidalarmmanager.RebootBroadcastReceiver"
    android:enabled="true"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
    </intent-filter>
</receiver>
```

### 2. Ensure minSdkVersion >= 21

In `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

### 3. Handle Android 14+ Permission (Important!)

On **Android 14+**, the `SCHEDULE_EXACT_ALARM` permission is **denied by default** for newly installed apps. Users must manually grant it in Settings.

Before scheduling tasks, check and request permission:

```dart
// Check if permission is granted
final canSchedule = await HybridRunner.canScheduleExactAlarms();

if (!canSchedule) {
  // Show dialog explaining why the permission is needed
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Permission Required'),
      content: Text(
        'To run tasks at exact times, please enable '
        '"Alarms & reminders" in Settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Later'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await HybridRunner.openExactAlarmSettings();
          },
          child: Text('Open Settings'),
        ),
      ],
    ),
  );
  return;
}

// Permission granted, safe to schedule
await HybridRunner.registerTask(...);
```

## Usage

### 1. Create the callback function

**IMPORTANT:** Must be a top-level function (outside of any class) with the `@pragma('vm:entry-point')` annotation.

```dart
@pragma('vm:entry-point')
Future<bool> myBackgroundTask() async {
  // Do heavy work here
  // Can run for 10+ minutes
  
  await syncDataToServer();
  await processLocalFiles();
  
  return true; // return false if failed
}
```

Why must it be top-level? Because the callback runs in a separate isolate, not in your app's main isolate.

### 2. Initialize in main()

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HybridRunner.initialize();
  runApp(MyApp());
}
```

### 3. Start the runner

```dart
await HybridRunner.start(
  callback: myBackgroundTask,
  loopInterval: Duration(minutes: 15),
  runImmediately: true,
  taskOverlapPolicy: TaskOverlapPolicy.parallel, // optional
);
```

#### Task Overlap Policy

Controls what happens when a new task is triggered while a previous task is still running:

| Policy | Behavior |
|--------|----------|
| `TaskOverlapPolicy.replace` | Cancel the running task, start the new one (default) |
| `TaskOverlapPolicy.skipIfRunning` | Ignore the new task if one is already running |
| `TaskOverlapPolicy.parallel` | Run both tasks simultaneously, no waiting |

Example use cases:
- **replace**: When you only care about the latest data sync
- **skipIfRunning**: When tasks should never overlap (e.g., database operations)
- **parallel**: When each task is independent (e.g., processing different files)

### 4. Stop if needed

```dart
await HybridRunner.stop();
```

### 5. Check status

```dart
bool isRunning = await HybridRunner.isActive;
Duration? interval = await HybridRunner.loopInterval;
```

## Multi-Task API

For more complex scenarios, you can register multiple named tasks with independent schedules.

### Register looping tasks

```dart
// Task 1: Sync data every 15 minutes
await HybridRunner.registerTask(
  name: 'syncData',
  callback: syncDataTask,
  interval: Duration(minutes: 15),
  taskOverlapPolicy: TaskOverlapPolicy.skipIfRunning,
);

// Task 2: Process files every 30 minutes
await HybridRunner.registerTask(
  name: 'processFiles',
  callback: processFilesTask,
  interval: Duration(minutes: 30),
  taskOverlapPolicy: TaskOverlapPolicy.parallel,
);
```

### Register one-time tasks

One-time tasks run once and are automatically removed after execution.

```dart
// Run once after 30 minutes
await HybridRunner.registerTask(
  name: 'sendReminder',
  callback: sendReminderTask,
  interval: Duration(minutes: 30),
  isOneTime: true, // Runs once, then removed
);

// Run immediately (1 second delay)
await HybridRunner.registerTask(
  name: 'initialSync',
  callback: initialSyncTask,
  interval: Duration(minutes: 1),
  isOneTime: true,
  runImmediately: true,
);
```

### View all registered tasks

```dart
final tasks = await HybridRunner.getRegisteredTasks();
for (final task in tasks) {
  print('Task: ${task.name}');
  print('  Interval: ${task.interval.inMinutes} minutes');
  print('  Active: ${task.isActive}');
  print('  One-time: ${task.isOneTime}');
  print('  Registered: ${task.registeredAt}');
}
```

### Stop a specific task

```dart
final stopped = await HybridRunner.stopTask('syncData');
print('Task stopped: $stopped'); // true if found and stopped
```

### Stop all tasks

```dart
await HybridRunner.stopAllTasks();
```

## How It Works

```
User starts runner
       ↓
Schedule AlarmManager (exact time)
       ↓
[Device sleep / App closed]
       ↓
AlarmManager fires! (max 10 sec)
       ↓
Enqueue WorkManager task
       ↓
WorkManager executes callback (max 10+ min)
       ↓
Schedule next alarm
       ↓
[Loop continues...]
```

## Verifying Background Execution

### Method 1: Using ADB Logcat

Connect your device via USB and run:

```bash
# Filter logs for HybridRunner
adb logcat -s HybridRunner:V

# Or filter by your app's tag
adb logcat | findstr "HybridRunner"   # Windows
adb logcat | grep "HybridRunner"       # Mac/Linux
```

Expected output when task runs:
```
D HybridRunner: Alarm triggered, enqueuing WorkManager task...
D HybridRunner: Policy: parallel - running with unique ID: hybridTask_1234567890
D HybridRunner: WorkManager task enqueued successfully
D HybridRunner: WorkManager task started: hybridTask
D HybridRunner: Executing task: syncData
D HybridRunner: Task syncData completed with result: true
D HybridRunner: Scheduling next alarm in 900 seconds
```

### Method 2: Database Logging (Recommended)

Log task executions to a local database so you can verify them later in the UI.

```dart
import 'package:sqflite/sqflite.dart';

@pragma('vm:entry-point')
Future<bool> myBackgroundTask() async {
  // Log to database
  final db = await openDatabase('task_logs.db');
  await db.insert('logs', {
    'timestamp': DateTime.now().toIso8601String(),
    'event': 'TASK_EXECUTED',
    'message': 'Background task ran successfully',
  });
  
  // Your actual task logic here
  await syncDataToServer();
  
  return true;
}
```

Then display these logs in your app's UI to verify background execution.

### Method 3: Step-by-Step Testing

1. **Start the runner** with a short interval (e.g., 1 minute)
   ```dart
   await HybridRunner.registerTask(
     name: 'test',
     callback: testTask,
     interval: Duration(minutes: 1),
     runImmediately: true,
   );
   ```

2. **Close the app** (swipe away, NOT force close)

3. **Wait for the interval** to pass

4. **Check logs** via ADB or open the app to see database logs

5. **Repeat** to verify multiple executions

### Test Checklist

| Scenario | How to Test |
|----------|-------------|
| App in foreground | Start runner, wait for interval |
| App in background | Minimize app, wait for interval |
| App closed (swiped away) | Close app, wait for interval, check logs |
| After device reboot | Reboot device, wait for interval |
| Screen off | Lock device, wait for interval |

### Common Issues

| Issue | Solution |
|-------|----------|
| Task doesn't run when app closed | Check battery optimization settings |
| Task delayed significantly | Enable "alarmClock" mode (already enabled by default) |
| Task stops after some time | Whitelist app from battery saver |
| No logs appearing | Ensure callback has `@pragma('vm:entry-point')` |

## Limitations

### Force Close
If the user force closes the app (from Settings > Apps > Force Stop), all alarms are cancelled. This is Android behavior, not a bug.

Workaround: This package also registers a WorkManager periodic task as backup. After ~15 minutes, the task will run again and re-schedule the alarm.

### Battery Optimization
Some vendors (Xiaomi, Oppo, Vivo, Samsung) have aggressive battery optimization that can kill background processes. Users need to whitelist the app in settings.

### No Minimum Interval
Unlike standalone WorkManager periodic tasks (which have a 15-minute minimum), the hybrid approach has **no minimum interval**. AlarmManager can trigger at any time, and WorkManager one-off tasks run immediately when enqueued.

The 15-minute minimum only applies to the **backup periodic task** - a fallback that runs if alarms are cancelled (e.g., after force close). This backup will re-schedule the alarm when it runs.

## Tips

1. **Test on a real device** - Emulator is sometimes not accurate for background behavior
2. **Don't force close** - Just swipe away or press back
3. **Whitelist from battery optimization** - Important for reliability
4. **Short intervals work** - Unlike pure WorkManager, you can use intervals < 15 minutes

## API Reference

### Single-Task API (Simple)

| Method | Description |
|--------|-------------|
| `HybridRunner.initialize()` | Initialize AlarmManager and WorkManager. Call once in `main()`. |
| `HybridRunner.start({...})` | Start a single task loop with the given callback and interval. |
| `HybridRunner.stop()` | Stop the single task loop. |
| `HybridRunner.isActive` | Check if the runner is currently active. |
| `HybridRunner.loopInterval` | Get the current loop interval. |

### Multi-Task API (Advanced)

| Method | Description |
|--------|-------------|
| `HybridRunner.registerTask({...})` | Register a named task (looping or one-time). |
| `HybridRunner.getRegisteredTasks()` | Get a list of all registered tasks. |
| `HybridRunner.stopTask(name)` | Stop and remove a specific task by name. |
| `HybridRunner.stopAllTasks()` | Stop all registered tasks. |

### Permission API (Android 12+)

| Method | Description |
|--------|-------------|
| `HybridRunner.canScheduleExactAlarms()` | Check if exact alarm permission is granted. Returns `true` on Android 11-. |
| `HybridRunner.openExactAlarmSettings()` | Open system settings for exact alarm permission. |

#### `registerTask` Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `String` | required | Unique task identifier |
| `callback` | `Function` | required | Top-level async function |
| `interval` | `Duration` | required | Interval (loop) or delay (one-time) |
| `taskOverlapPolicy` | `TaskOverlapPolicy` | `replace` | Overlap behavior |
| `runImmediately` | `bool` | `false` | Start immediately |
| `isOneTime` | `bool` | `false` | Run once then auto-remove |

### Classes & Enums

| Type | Description |
|------|-------------|
| `TaskOverlapPolicy` | Enum: `replace`, `skipIfRunning`, `parallel` |
| `RegisteredTask` | Task model with: `name`, `interval`, `isActive`, `isOneTime`, `registeredAt` |

## License

MIT
