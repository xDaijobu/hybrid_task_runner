import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:hybrid_task_runner/hybrid_task_runner.dart';
import 'package:intl/intl.dart';

import 'app_lifecycle_tracker.dart';
import 'task_log_database.dart';

/// The user's heavy task function.
///
/// This MUST be a top-level function (not a method inside a class).
/// This MUST have the @pragma('vm:entry-point') annotation for release builds.
///
/// This function will be executed by WorkManager and can run for 10+ minutes.
@pragma('vm:entry-point')
Future<bool> myHeavyTask() async {
  final startTime = DateTime.now();

  // Check if app is in foreground or background
  final isAppInForeground = await AppLifecycleTracker.isInForeground();
  final executionContext = isAppInForeground ? 'FOREGROUND' : 'BACKGROUND';

  developer.log(
    '[MyHeavyTask] Starting heavy task at $startTime ($executionContext)',
    name: 'ExampleApp',
  );

  // Log task start to database
  await TaskLogDatabase.insert(
    TaskLog(
      timestamp: startTime,
      event: 'TASK_STARTED',
      message: 'Heavy task started execution ($executionContext)',
      success: true,
      isBackground: !isAppInForeground, // true if app is in background
    ),
  );

  try {
    // Simulate a long-running task (30 seconds for demo purposes)
    // In a real app, this could be:
    // - Syncing data with a server
    // - Processing files
    // - Uploading media
    // - Running ML inference
    await Future.delayed(const Duration(seconds: 30));

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    // Check state again at completion (app might have been opened/closed during execution)
    final isStillInForeground = await AppLifecycleTracker.isInForeground();
    final completionContext = isStillInForeground ? 'FOREGROUND' : 'BACKGROUND';

    developer.log(
      '[MyHeavyTask] Heavy task completed at $endTime (took ${duration.inSeconds}s) ($completionContext)',
      name: 'ExampleApp',
    );

    // Log task completion to database
    await TaskLogDatabase.insert(
      TaskLog(
        timestamp: endTime,
        event: 'TASK_COMPLETED',
        message:
            'Heavy task completed in ${duration.inSeconds}s ($completionContext)',
        success: true,
        isBackground: !isStillInForeground,
      ),
    );

    return true;
  } catch (e) {
    final errorTime = DateTime.now();
    final isStillInForeground = await AppLifecycleTracker.isInForeground();
    final errorContext = isStillInForeground ? 'FOREGROUND' : 'BACKGROUND';

    developer.log(
      '[MyHeavyTask] Heavy task failed: $e ($errorContext)',
      name: 'ExampleApp',
    );

    // Log task failure to database
    await TaskLogDatabase.insert(
      TaskLog(
        timestamp: errorTime,
        event: 'TASK_FAILED',
        message: 'Heavy task failed with error: $e ($errorContext)',
        success: false,
        isBackground: !isStillInForeground,
      ),
    );

    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize the HybridRunner before runApp
    // ignore: deprecated_member_use
    await HybridRunner.initialize();
    developer.log('HybridRunner initialized successfully', name: 'ExampleApp');
  } catch (e, stack) {
    developer.log('Failed to initialize HybridRunner: $e', name: 'ExampleApp');
    developer.log('Stack: $stack', name: 'ExampleApp');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hybrid Task Runner Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E8B7E), // Calm sage/teal
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _isRunning = false;
  Duration _interval = const Duration(minutes: 1);
  String _status = 'Not started';
  int _logCount = 0;
  bool _hasExactAlarmPermission = true; // Assume true until checked

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Mark app as in foreground when it starts
    AppLifecycleTracker.setForeground();
    _checkStatus();
    _updateLogCount();
    _checkExactAlarmPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground
        AppLifecycleTracker.setForeground();
        developer.log('App is now in FOREGROUND', name: 'ExampleApp');
        // Refresh log count when returning to foreground
        _updateLogCount();
        // Re-check permission (user may have granted it in settings)
        _checkExactAlarmPermission();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is in background
        AppLifecycleTracker.setBackground();
        developer.log('App is now in BACKGROUND', name: 'ExampleApp');
        break;
    }
  }

  Future<void> _checkStatus() async {
    final isActive = await HybridRunner.isActive;
    final interval = await HybridRunner.loopInterval;

    setState(() {
      _isRunning = isActive;
      if (interval != null) {
        _interval = interval;
      }
      _status = isActive ? 'Running' : 'Stopped';
    });
  }

  Future<void> _updateLogCount() async {
    final count = await TaskLogDatabase.count();
    setState(() {
      _logCount = count;
    });
  }

  Future<void> _checkExactAlarmPermission() async {
    final hasPermission = await HybridRunner.canScheduleExactAlarms();
    setState(() {
      _hasExactAlarmPermission = hasPermission;
    });
  }

  Future<void> _showPermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'To run tasks at exact times, please enable '
          '"Alarms & reminders" in Settings.\n\n'
          'Without this permission, task timing may be delayed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (result == true) {
      await HybridRunner.openExactAlarmSettings();
    }
  }

  Future<void> _startRunner() async {
    try {
      // Check permission first on Android 12+
      final hasPermission = await HybridRunner.canScheduleExactAlarms();
      if (!hasPermission) {
        // Show permission dialog
        await _showPermissionDialog();
        // Re-check after returning from settings
        await _checkExactAlarmPermission();
        if (!_hasExactAlarmPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permission required for exact timing'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return; // Don't start without permission
        }
      }

      await HybridRunner.start(
        callback: myHeavyTask,
        loopInterval: _interval,
        runImmediately: true,
      );

      // Log the start event
      await TaskLogDatabase.insert(
        TaskLog(
          timestamp: DateTime.now(),
          event: 'RUNNER_STARTED',
          message:
              'Hybrid runner started with ${_interval.inMinutes}min interval',
          success: true,
        ),
      );

      setState(() {
        _isRunning = true;
        _status = 'Running - Next task in ${_interval.inMinutes} minutes';
      });

      await _updateLogCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hybrid Task Runner started!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRunner() async {
    await HybridRunner.stop();

    // Log the stop event
    await TaskLogDatabase.insert(
      TaskLog(
        timestamp: DateTime.now(),
        event: 'RUNNER_STOPPED',
        message: 'Hybrid runner stopped by user',
        success: true,
      ),
    );

    setState(() {
      _isRunning = false;
      _status = 'Stopped';
    });

    await _updateLogCount();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hybrid Task Runner stopped'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _viewLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LogViewerPage()),
    ).then((_) => _updateLogCount());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hybrid Task Runner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Badge(
            label: Text('$_logCount'),
            isLabelVisible: _logCount > 0,
            child: IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'View Logs',
              onPressed: _viewLogs,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isRunning ? Icons.play_circle : Icons.stop_circle,
                          color: _isRunning ? Colors.green : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Status: $_status',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Interval: ${_interval.inMinutes} minutes',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      'Logs recorded: $_logCount',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Permission Status Card (Android 12+)
            if (!_hasExactAlarmPermission)
              Card(
                color: Colors.orange.shade900.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        color: Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Exact Alarm Permission Required',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Android 14+ requires manual permission grant',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _showPermissionDialog,
                        child: const Text('Grant'),
                      ),
                    ],
                  ),
                ),
              ),

            // Interval Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loop Interval',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _interval.inMinutes.toDouble(),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      label: '${_interval.inMinutes} min',
                      onChanged: _isRunning
                          ? null
                          : (value) {
                              setState(() {
                                _interval = Duration(minutes: value.round());
                              });
                            },
                    ),
                    Text(
                      'Note: Android may delay tasks in Doze mode. '
                      'For reliable execution, use 15+ minutes.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _startRunner,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? _stopRunner : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // View Logs Button
            ElevatedButton.icon(
              onPressed: _viewLogs,
              icon: const Icon(Icons.list_alt),
              label: Text('View Task Logs ($_logCount)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const Spacer(),

            // Info section
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How it works',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. AlarmManager fires at the scheduled time\n'
                      '2. Alarm enqueues a WorkManager task\n'
                      '3. WorkManager runs your heavy task (30s demo)\n'
                      '4. After completion, next alarm is scheduled\n\n'
                      'All task executions are logged to the database.\n'
                      'Check "View Task Logs" to verify background execution!',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page for viewing task execution logs.
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  List<TaskLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await TaskLogDatabase.getAll();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs?'),
        content: const Text('This will delete all task execution logs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TaskLogDatabase.clear();
      await _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Logs cleared')));
      }
    }
  }

  Color _getEventColor(String event) {
    switch (event) {
      case 'RUNNER_STARTED':
        return Colors.blue;
      case 'RUNNER_STOPPED':
        return Colors.orange;
      case 'TASK_STARTED':
        return Colors.purple;
      case 'TASK_COMPLETED':
        return Colors.green;
      case 'TASK_FAILED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getEventIcon(String event) {
    switch (event) {
      case 'RUNNER_STARTED':
        return Icons.play_circle_outline;
      case 'RUNNER_STOPPED':
        return Icons.stop_circle_outlined;
      case 'TASK_STARTED':
        return Icons.pending_outlined;
      case 'TASK_COMPLETED':
        return Icons.check_circle_outline;
      case 'TASK_FAILED':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Logs'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Logs',
            onPressed: _logs.isEmpty ? null : _clearLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No logs yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start the runner to generate logs',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  final color = _getEventColor(log.event);
                  final icon = _getEventIcon(log.event);
                  // Orange tint for background, normal for foreground
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 0,
                    ),
                    color: log.isBackground
                        ? Colors.orange.withValues(alpha: 0.15)
                        : null,
                    shape: log.isBackground
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.orange.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          )
                        : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.2),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      title: Text(
                        log.event.replaceAll('_', ' '),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(log.message),
                          const SizedBox(height: 4),
                          Text(
                            dateFormat.format(log.timestamp),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Icon(
                        log.success ? Icons.check_circle : Icons.cancel,
                        color: log.success ? Colors.green : Colors.red,
                        size: 16,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
