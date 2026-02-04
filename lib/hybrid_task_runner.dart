/// A Flutter package implementing a Hybrid Background Strategy.
///
/// Uses AlarmManager for precision scheduling and WorkManager for reliable
/// long-running task execution on Android.
///
/// ## Usage
///
/// ```dart
/// import 'package:hybrid_task_runner/hybrid_task_runner.dart';
///
/// // Your heavy task - MUST be a top-level function
/// @pragma('vm:entry-point')
/// Future<bool> myHeavyTask() async {
///   // Do heavy work here (can run for 10+ minutes)
///   await Future.delayed(Duration(minutes: 2));
///   print('Task completed!');
///   return true;
/// }
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Initialize the hybrid runner
///   await HybridRunner.initialize();
///
///   // Start the task loop
///   await HybridRunner.start(
///     callback: myHeavyTask,
///     loopInterval: Duration(minutes: 15),
///   );
///
///   runApp(MyApp());
/// }
/// ```
library;

import 'dart:developer' as developer;
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';

import 'src/callbacks.dart';
import 'src/constants.dart';
import 'src/registered_task.dart';
import 'src/storage.dart';

export 'src/callbacks.dart' show alarmCallback, workmanagerCallbackDispatcher;
export 'src/constants.dart';
export 'src/registered_task.dart';
export 'src/storage.dart';

/// Log tag for debugging.
const String _logTag = 'HybridRunner';

/// Type definition for the user's background task callback.
///
/// The callback must be a top-level or static function and should return
/// `true` if the task completed successfully, `false` otherwise.
typedef HybridTaskCallback = Future<bool> Function();

/// Policy for handling task overlap when a new task is triggered
/// while a previous task is still running.
enum TaskOverlapPolicy {
  /// Replace the currently running task with the new one.
  /// The old task may be cancelled.
  replace,

  /// Skip the new task if there's already one running.
  /// The new task will be ignored.
  skipIfRunning,

  /// Run tasks in parallel without waiting.
  /// Each task gets a unique ID and runs independently.
  parallel,
}

/// Main class for the Hybrid Task Runner.
///
/// Implements a hybrid background strategy that uses:
/// - **AlarmManager**: For precision scheduling (fires at exact times)
/// - **WorkManager**: For reliable task execution (10+ minute execution window)
///
/// ## Flow
///
/// 1. Alarm fires at the scheduled time
/// 2. Alarm callback enqueues a WorkManager task
/// 3. WorkManager executes the user's heavy task
/// 4. Before finishing, WorkManager reschedules the next alarm
class HybridRunner {
  HybridRunner._();

  static bool _initialized = false;

  /// Initializes both AlarmManager and WorkManager plugins.
  ///
  /// This should be called once in your `main()` function before using
  /// any other HybridRunner methods.
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await HybridRunner.initialize();
  ///   runApp(MyApp());
  /// }
  /// ```
  ///
  /// [isDebugMode] parameter is deprecated and has no effect in workmanager 0.9.0+.
  @Deprecated(
    'isDebugMode parameter is no longer supported in workmanager 0.9.0+',
  )
  static Future<void> initialize({bool isDebugMode = false}) async {
    if (_initialized) {
      developer.log('Already initialized', name: _logTag);
      return;
    }

    developer.log('Initializing HybridRunner...', name: _logTag);

    // Initialize AlarmManager
    final alarmResult = await AndroidAlarmManager.initialize();
    developer.log('AlarmManager initialized: $alarmResult', name: _logTag);

    // Initialize WorkManager with the callback dispatcher
    // Note: isInDebugMode is deprecated in workmanager 0.9.0
    await Workmanager().initialize(workmanagerCallbackDispatcher);
    developer.log('WorkManager initialized', name: _logTag);

    _initialized = true;
    developer.log('HybridRunner initialization complete', name: _logTag);
  }

  /// Starts the hybrid task loop.
  ///
  /// [callback] is the heavy task function that will run inside WorkManager.
  /// It MUST be a top-level or static function with the signature
  /// `Future<bool> Function()`. The function should be annotated with
  /// `@pragma('vm:entry-point')` to ensure it's not tree-shaken in release builds.
  ///
  /// [loopInterval] is the duration between task executions.
  ///
  /// [runImmediately] if true, the first task will be triggered immediately.
  /// Default is false, which schedules the first alarm for [loopInterval] later.
  ///
  /// [taskOverlapPolicy] controls what happens when a new task is triggered
  /// while a previous task is still running:
  /// - [TaskOverlapPolicy.replace]: Cancel old task, run new one (default)
  /// - [TaskOverlapPolicy.skipIfRunning]: Ignore new task if one is running
  /// - [TaskOverlapPolicy.parallel]: Run both tasks simultaneously
  ///
  /// Throws [ArgumentError] if the callback is not a valid top-level or static function.
  ///
  /// Example:
  /// ```dart
  /// @pragma('vm:entry-point')
  /// Future<bool> myHeavyTask() async {
  ///   await performHeavyWork();
  ///   return true;
  /// }
  ///
  /// await HybridRunner.start(
  ///   callback: myHeavyTask,
  ///   loopInterval: Duration(minutes: 30),
  ///   taskOverlapPolicy: TaskOverlapPolicy.parallel,
  /// );
  /// ```
  static Future<void> start({
    required HybridTaskCallback callback,
    required Duration loopInterval,
    bool runImmediately = false,
    TaskOverlapPolicy taskOverlapPolicy = TaskOverlapPolicy.replace,
  }) async {
    _ensureInitialized();

    developer.log('Starting HybridRunner...', name: _logTag);

    // Validate the callback
    final callbackHandle = PluginUtilities.getCallbackHandle(callback);
    if (callbackHandle == null) {
      throw ArgumentError(
        'The callback must be a top-level or static function. '
        'Instance methods and closures are not supported.',
      );
    }

    // Store the callback handle, interval, and policy
    await HybridStorage.storeCallbackHandle(callbackHandle);
    await HybridStorage.storeLoopInterval(loopInterval);
    await HybridStorage.storeTaskOverlapPolicy(taskOverlapPolicy.index);
    await HybridStorage.setActive(true);

    developer.log(
      'Stored callback handle: ${callbackHandle.toRawHandle()}',
      name: _logTag,
    );
    developer.log(
      'Loop interval: ${loopInterval.inSeconds} seconds',
      name: _logTag,
    );
    developer.log(
      'Task overlap policy: ${taskOverlapPolicy.name}',
      name: _logTag,
    );

    // Schedule the first alarm
    if (runImmediately) {
      developer.log('Running first task immediately...', name: _logTag);
      // Schedule almost immediately (1 second delay for safety)
      await AndroidAlarmManager.oneShot(
        const Duration(seconds: 1),
        kAlarmId,
        alarmCallback,
        exact: true,
        wakeup: true,
        alarmClock: true,
        rescheduleOnReboot: true,
      );
    } else {
      developer.log(
        'Scheduling first alarm for ${loopInterval.inSeconds} seconds from now',
        name: _logTag,
      );
      await AndroidAlarmManager.oneShot(
        loopInterval,
        kAlarmId,
        alarmCallback,
        exact: true,
        wakeup: true,
        alarmClock: true,
        rescheduleOnReboot: true,
      );
    }

    // Also register a WorkManager periodic task as backup
    // This will run even if the app is force closed (after some delay)
    // Minimum interval for periodic is 15 minutes
    final periodicInterval = loopInterval.inMinutes >= 15
        ? loopInterval
        : const Duration(minutes: 15);

    await Workmanager().registerPeriodicTask(
      '${kWorkManagerTaskName}_periodic',
      kWorkManagerTaskName,
      frequency: periodicInterval,
      tag: kWorkManagerTaskTag,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );

    developer.log('HybridRunner started successfully', name: _logTag);
    developer.log(
      'Periodic backup task registered with ${periodicInterval.inMinutes}min interval',
      name: _logTag,
    );
  }

  /// Stops the hybrid task loop.
  ///
  /// This cancels any pending alarms and WorkManager tasks.
  /// Any currently running task will be allowed to complete.
  static Future<void> stop() async {
    _ensureInitialized();

    developer.log('Stopping HybridRunner...', name: _logTag);

    // Mark as inactive first
    await HybridStorage.setActive(false);

    // Cancel any pending alarms
    await AndroidAlarmManager.cancel(kAlarmId);
    developer.log('Alarm cancelled', name: _logTag);

    // Cancel any pending WorkManager tasks
    await Workmanager().cancelByTag(kWorkManagerTaskTag);
    developer.log('WorkManager tasks cancelled', name: _logTag);

    // Clear stored data
    await HybridStorage.clear();

    developer.log('HybridRunner stopped', name: _logTag);
  }

  /// Returns whether the hybrid runner is currently active.
  static Future<bool> get isActive async {
    return HybridStorage.isActive();
  }

  /// Returns the current loop interval, or null if not set.
  static Future<Duration?> get loopInterval async {
    return HybridStorage.getLoopInterval();
  }

  // ============================================
  // Permission API (Android 12+)
  // ============================================

  /// Checks if the app can schedule exact alarms.
  ///
  /// On Android 12+ (API 31+), this requires the `SCHEDULE_EXACT_ALARM` permission.
  /// On Android 14+ (API 34+), this permission is **denied by default** for newly
  /// installed apps targeting API 33+. Users must manually grant this permission
  /// in system Settings > Apps > Alarms & reminders.
  ///
  /// Returns `true` if:
  /// - The app has permission to schedule exact alarms, OR
  /// - The device is running Android 11 or lower (no permission needed), OR
  /// - The platform is not Android (iOS, web, etc.)
  ///
  /// Example:
  /// ```dart
  /// final canSchedule = await HybridRunner.canScheduleExactAlarms();
  /// if (!canSchedule) {
  ///   // Show dialog explaining why permission is needed
  ///   // Then offer to open settings
  ///   await HybridRunner.openExactAlarmSettings();
  /// }
  /// ```
  static Future<bool> canScheduleExactAlarms() async {
    final status = await Permission.scheduleExactAlarm.status;
    developer.log('Exact alarm permission status: $status', name: _logTag);
    return status.isGranted;
  }

  /// Opens the system settings page for exact alarm permission.
  ///
  /// On Android 12+, this opens Settings > Apps > [Your App] > Alarms & reminders.
  /// Users must enable the toggle for exact alarms to work.
  ///
  /// On platforms/versions where this setting is not available, this method
  /// will attempt to open the app settings page instead.
  ///
  /// Returns `true` if the settings page was opened successfully.
  ///
  /// Example:
  /// ```dart
  /// // Show dialog first explaining why permission is needed
  /// showDialog(
  ///   context: context,
  ///   builder: (context) => AlertDialog(
  ///     title: Text('Permission Required'),
  ///     content: Text('To run tasks at exact times, please enable '
  ///         '"Alarms & reminders" in the next screen.'),
  ///     actions: [
  ///       TextButton(
  ///         onPressed: () => Navigator.pop(context),
  ///         child: Text('Cancel'),
  ///       ),
  ///       TextButton(
  ///         onPressed: () async {
  ///           Navigator.pop(context);
  ///           await HybridRunner.openExactAlarmSettings();
  ///         },
  ///         child: Text('Open Settings'),
  ///       ),
  ///     ],
  ///   ),
  /// );
  /// ```
  static Future<bool> openExactAlarmSettings() async {
    developer.log('Opening exact alarm settings...', name: _logTag);
    final opened = await openAppSettings();
    developer.log('Settings opened: $opened', name: _logTag);
    return opened;
  }

  // ============================================
  // Multi-task API
  // ============================================

  /// Registers a named task with its own schedule and configuration.
  ///
  /// [name] is a unique identifier for this task. If a task with the same
  /// name already exists, it will be replaced.
  ///
  /// [callback] is the heavy task function that will run inside WorkManager.
  /// It MUST be a top-level or static function.
  ///
  /// [interval] is the duration between task executions (for looping tasks),
  /// or the delay before execution (for one-time tasks).
  ///
  /// [taskOverlapPolicy] controls what happens when this task is triggered
  /// while a previous execution is still running.
  ///
  /// [runImmediately] if true, the first task will be triggered immediately.
  ///
  /// [isOneTime] if true, the task runs once and is automatically removed.
  /// Use this for one-shot operations like migrations or delayed notifications.
  ///
  /// Example (looping task):
  /// ```dart
  /// await HybridRunner.registerTask(
  ///   name: 'syncData',
  ///   callback: syncDataTask,
  ///   interval: Duration(minutes: 15),
  /// );
  /// ```
  ///
  /// Example (one-time task):
  /// ```dart
  /// await HybridRunner.registerTask(
  ///   name: 'sendReminder',
  ///   callback: sendReminderTask,
  ///   interval: Duration(minutes: 30), // runs once after 30 min
  ///   isOneTime: true,
  /// );
  /// ```
  static Future<void> registerTask({
    required String name,
    required HybridTaskCallback callback,
    required Duration interval,
    TaskOverlapPolicy taskOverlapPolicy = TaskOverlapPolicy.replace,
    bool runImmediately = false,
    bool isOneTime = false,
  }) async {
    _ensureInitialized();

    final taskType = isOneTime ? 'one-time' : 'looping';
    developer.log('Registering $taskType task: $name', name: _logTag);

    // Validate the callback
    final callbackHandle = PluginUtilities.getCallbackHandle(callback);
    if (callbackHandle == null) {
      throw ArgumentError(
        'The callback must be a top-level or static function. '
        'Instance methods and closures are not supported.',
      );
    }

    // Get or assign an alarm ID for this task
    final existingTask = await HybridStorage.getTask(name);
    final alarmId =
        existingTask?.alarmId ?? await HybridStorage.getNextAlarmId();

    // Create the task record
    final task = RegisteredTask(
      name: name,
      callbackHandle: callbackHandle.toRawHandle(),
      intervalMs: interval.inMilliseconds,
      overlapPolicyIndex: taskOverlapPolicy.index,
      isActive: true,
      alarmId: alarmId,
      registeredAt: DateTime.now(),
      isOneTime: isOneTime,
    );

    // Save to storage
    await HybridStorage.saveTask(task);

    developer.log(
      'Task $name registered with alarmId: $alarmId, interval: ${interval.inSeconds}s, oneTime: $isOneTime',
      name: _logTag,
    );

    // Schedule the alarm
    final initialDelay = runImmediately ? const Duration(seconds: 1) : interval;

    await AndroidAlarmManager.oneShot(
      initialDelay,
      alarmId,
      alarmCallback,
      exact: true,
      wakeup: true,
      alarmClock: true,
      rescheduleOnReboot:
          !isOneTime, // Don't reschedule one-time tasks on reboot
    );

    developer.log('Task $name alarm scheduled', name: _logTag);

    // For looping tasks, also register the backup periodic task
    if (!isOneTime) {
      final periodicInterval = interval.inMinutes >= 15
          ? interval
          : const Duration(minutes: 15);

      await Workmanager().registerPeriodicTask(
        '${kWorkManagerTaskName}_${name}_periodic',
        kWorkManagerTaskName,
        frequency: periodicInterval,
        tag: '${kWorkManagerTaskTag}_$name',
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.notRequired),
      );
    }

    developer.log('Task $name registered successfully', name: _logTag);
  }

  /// Returns all registered tasks.
  ///
  /// Example:
  /// ```dart
  /// final tasks = await HybridRunner.getRegisteredTasks();
  /// for (final task in tasks) {
  ///   print('Task: ${task.name}, Active: ${task.isActive}');
  /// }
  /// ```
  static Future<List<RegisteredTask>> getRegisteredTasks() async {
    return HybridStorage.getAllTasks();
  }

  /// Stops and removes a specific task by name.
  ///
  /// Returns true if the task was found and stopped, false if not found.
  ///
  /// Example:
  /// ```dart
  /// final stopped = await HybridRunner.stopTask('syncData');
  /// print('Task stopped: $stopped');
  /// ```
  static Future<bool> stopTask(String name) async {
    _ensureInitialized();

    developer.log('Stopping task: $name', name: _logTag);

    final task = await HybridStorage.getTask(name);
    if (task == null) {
      developer.log('Task $name not found', name: _logTag);
      return false;
    }

    // Cancel the alarm
    await AndroidAlarmManager.cancel(task.alarmId);
    developer.log('Alarm ${task.alarmId} cancelled', name: _logTag);

    // Cancel WorkManager tasks for this task
    await Workmanager().cancelByTag('${kWorkManagerTaskTag}_$name');
    developer.log('WorkManager tasks for $name cancelled', name: _logTag);

    // Remove from storage
    await HybridStorage.removeTask(name);

    developer.log('Task $name stopped and removed', name: _logTag);
    return true;
  }

  /// Stops all registered tasks.
  ///
  /// Example:
  /// ```dart
  /// await HybridRunner.stopAllTasks();
  /// ```
  static Future<void> stopAllTasks() async {
    _ensureInitialized();

    developer.log('Stopping all tasks...', name: _logTag);

    final tasks = await HybridStorage.getAllTasks();

    for (final task in tasks) {
      await AndroidAlarmManager.cancel(task.alarmId);
      await Workmanager().cancelByTag('${kWorkManagerTaskTag}_${task.name}');
    }

    // Clear all task data
    await HybridStorage.clearAll();

    // Also cancel legacy tasks
    await AndroidAlarmManager.cancel(kAlarmId);
    await Workmanager().cancelByTag(kWorkManagerTaskTag);

    developer.log('All tasks stopped', name: _logTag);
  }

  /// Ensures the runner has been initialized.
  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'HybridRunner has not been initialized. '
        'Call HybridRunner.initialize() before using other methods.',
      );
    }
  }
}
