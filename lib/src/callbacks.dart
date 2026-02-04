import 'dart:developer' as developer;
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'constants.dart';
import 'registered_task.dart';
import 'storage.dart';

/// Log tag for debugging.
const String _logTag = 'HybridRunner';

/// Callback function triggered by AlarmManager (legacy single-task mode).
///
/// This function runs in a separate isolate from the main app.
/// It MUST be a top-level or static function.
/// It MUST have the @pragma('vm:entry-point') annotation for release builds.
///
/// This callback has a short execution window (~10 seconds), so it should
/// only enqueue a WorkManager task and exit quickly.
@pragma('vm:entry-point')
Future<void> alarmCallback() async {
  // Initialize Flutter binding for the isolate
  WidgetsFlutterBinding.ensureInitialized();

  developer.log(
    'Alarm triggered, enqueuing WorkManager task...',
    name: _logTag,
  );

  try {
    // Get the stored task overlap policy
    final policyIndex = await HybridStorage.getTaskOverlapPolicy();

    // Determine task ID and policy based on TaskOverlapPolicy
    // 0 = replace, 1 = skipIfRunning, 2 = parallel
    String taskId;
    ExistingWorkPolicy workPolicy;

    switch (policyIndex) {
      case 1: // skipIfRunning - use fixed ID with keep policy
        taskId = kWorkManagerTaskName;
        workPolicy = ExistingWorkPolicy.keep;
        developer.log(
          'Policy: skipIfRunning - keeping existing task if running',
          name: _logTag,
        );
        break;
      case 2: // parallel - always unique ID, no conflict
        taskId =
            '${kWorkManagerTaskName}_${DateTime.now().microsecondsSinceEpoch}';
        workPolicy = ExistingWorkPolicy.keep; // doesn't matter, ID is unique
        developer.log(
          'Policy: parallel - running with unique ID: $taskId',
          name: _logTag,
        );
        break;
      default: // 0 = replace - use fixed ID with replace policy
        taskId = kWorkManagerTaskName;
        workPolicy = ExistingWorkPolicy.replace;
        developer.log(
          'Policy: replace - replacing existing task if running',
          name: _logTag,
        );
    }

    // Enqueue a WorkManager OneOffTask
    await Workmanager().registerOneOffTask(
      taskId,
      kWorkManagerTaskName,
      existingWorkPolicy: workPolicy,
      tag: kWorkManagerTaskTag,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );

    developer.log('WorkManager task enqueued successfully', name: _logTag);
  } catch (e, stackTrace) {
    developer.log(
      'Failed to enqueue WorkManager task: $e',
      name: _logTag,
      error: e,
      stackTrace: stackTrace,
    );
  }
}

/// WorkManager callback dispatcher.
///
/// This function runs in a separate isolate from the main app.
/// It MUST be a top-level function.
/// It MUST have the @pragma('vm:entry-point') annotation for release builds.
///
/// This callback has a longer execution window (~10+ minutes) and is responsible
/// for executing the user's heavy task and rescheduling the next alarm.
@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Initialize Flutter binding for the isolate
    WidgetsFlutterBinding.ensureInitialized();

    developer.log('WorkManager task started: $task', name: _logTag);

    if (task == kWorkManagerTaskName || task == Workmanager.iOSBackgroundTask) {
      try {
        // First, try to handle multi-task mode
        final multiTaskResult = await _executeMultiTaskMode(inputData);
        if (multiTaskResult != null) {
          return Future.value(multiTaskResult);
        }

        // Fall back to legacy single-task mode
        return await _executeLegacySingleTaskMode();
      } catch (e, stackTrace) {
        developer.log(
          'Error executing task: $e',
          name: _logTag,
          error: e,
          stackTrace: stackTrace,
        );
        return Future.value(false);
      }
    }

    developer.log('Unknown task: $task', name: _logTag);
    return Future.value(false);
  });
}

/// Executes a task in multi-task mode.
/// Returns null if no multi-task is configured, otherwise returns the result.
Future<bool?> _executeMultiTaskMode(Map<String, dynamic>? inputData) async {
  // Check if we have any registered tasks
  final tasks = await HybridStorage.getAllTasks();
  if (tasks.isEmpty) {
    developer.log(
      'No registered tasks found, falling back to legacy mode',
      name: _logTag,
    );
    return null;
  }

  developer.log(
    'Multi-task mode: ${tasks.length} registered tasks',
    name: _logTag,
  );

  // Execute all active tasks
  bool allSuccessful = true;
  for (final task in tasks) {
    if (!task.isActive) {
      developer.log('Skipping inactive task: ${task.name}', name: _logTag);
      continue;
    }

    developer.log('Executing task: ${task.name}', name: _logTag);

    try {
      // Get the callback from the stored handle
      final handle = CallbackHandle.fromRawHandle(task.callbackHandle);
      final callback = PluginUtilities.getCallbackFromHandle(handle);

      if (callback == null) {
        developer.log(
          'Failed to get callback for task: ${task.name}',
          name: _logTag,
        );
        allSuccessful = false;
        continue;
      }

      // Execute the callback
      final typedCallback = callback as Future<bool> Function();
      final result = await typedCallback();

      developer.log(
        'Task ${task.name} completed with result: $result',
        name: _logTag,
      );

      if (!result) {
        allSuccessful = false;
      }

      // Handle one-time vs looping tasks
      if (task.isOneTime) {
        // One-time task: remove it after execution
        developer.log('Removing one-time task: ${task.name}', name: _logTag);
        await HybridStorage.removeTask(task.name);
      } else {
        // Looping task: reschedule the alarm
        await _rescheduleTaskAlarm(task);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error executing task ${task.name}: $e',
        name: _logTag,
        error: e,
        stackTrace: stackTrace,
      );
      allSuccessful = false;
    }
  }

  return allSuccessful;
}

/// Reschedules the alarm for a specific task.
Future<void> _rescheduleTaskAlarm(RegisteredTask task) async {
  developer.log(
    'Scheduling next alarm for ${task.name} in ${task.interval.inSeconds}s',
    name: _logTag,
  );

  await AndroidAlarmManager.oneShot(
    task.interval,
    task.alarmId,
    alarmCallback,
    exact: true,
    wakeup: true,
    alarmClock: true,
    rescheduleOnReboot: true,
  );

  developer.log('Next alarm scheduled for ${task.name}', name: _logTag);
}

/// Executes the legacy single-task mode.
Future<bool> _executeLegacySingleTaskMode() async {
  developer.log('Using legacy single-task mode', name: _logTag);

  // Check if the runner is still active
  final isActive = await HybridStorage.isActive();
  if (!isActive) {
    developer.log(
      'Runner is not active, skipping task execution',
      name: _logTag,
    );
    return true;
  }

  // Retrieve the stored callback handle
  final callbackHandle = await HybridStorage.getCallbackHandle();
  if (callbackHandle == null) {
    developer.log(
      'No callback handle found, cannot execute task',
      name: _logTag,
    );
    return false;
  }

  // Get the callback function from the handle
  final callback = PluginUtilities.getCallbackFromHandle(callbackHandle);
  if (callback == null) {
    developer.log('Failed to retrieve callback from handle', name: _logTag);
    return false;
  }

  developer.log('Executing user callback...', name: _logTag);

  // Execute the user's callback
  final typedCallback = callback as Future<bool> Function();
  final result = await typedCallback();

  developer.log('User callback completed with result: $result', name: _logTag);

  // Reschedule the next alarm if still active
  final stillActive = await HybridStorage.isActive();
  if (stillActive) {
    final interval = await HybridStorage.getLoopInterval();
    if (interval != null) {
      developer.log(
        'Scheduling next alarm in ${interval.inSeconds} seconds',
        name: _logTag,
      );

      await AndroidAlarmManager.oneShot(
        interval,
        kAlarmId,
        alarmCallback,
        exact: true,
        wakeup: true,
        alarmClock: true,
        rescheduleOnReboot: true,
      );

      developer.log('Next alarm scheduled successfully', name: _logTag);
    }
  }

  return result;
}
