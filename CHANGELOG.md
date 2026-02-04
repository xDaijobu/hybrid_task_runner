# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - Unreleased

### Added

- **Permission API** for Android 12+ exact alarm permission handling
  - `HybridRunner.canScheduleExactAlarms()` - Check if exact alarms are allowed
  - `HybridRunner.openExactAlarmSettings()` - Open system settings for permission grant
- Added `permission_handler` dependency

### Changed

- **BREAKING**: Removed `USE_EXACT_ALARM` permission from package manifest
  - This permission is only for calendar/alarm apps per Google Play policy
  - Apps must now check permission and guide users to Settings on Android 14+
- Updated README with Android 14+ permission handling guide
- Updated example app with permission status card and grant button

## [1.1.1] - 2026-02-04

### Documentation

- Updated installation instructions to use `flutter pub add`
- Added pub.dev badge to README
- Updated `pubspec.yaml` metadata

## [1.1.0] - 2026-02-04

### Added

- **Task Overlap Policy** - Control what happens when tasks overlap
  - `TaskOverlapPolicy.replace` - Cancel running task, start new one (default)
  - `TaskOverlapPolicy.skipIfRunning` - Ignore new task if one is running
  - `TaskOverlapPolicy.parallel` - Run both tasks simultaneously

- **Multi-Task API** - Register multiple named tasks with independent schedules
  - `HybridRunner.registerTask()` - Register a named task
  - `HybridRunner.getRegisteredTasks()` - List all registered tasks
  - `HybridRunner.stopTask(name)` - Stop a specific task by name
  - `HybridRunner.stopAllTasks()` - Stop all registered tasks

- **One-Time Tasks** - Tasks that run once and are automatically removed
  - New `isOneTime` parameter in `registerTask()`
  - One-time tasks don't get backup periodic WorkManager tasks

- **RegisteredTask Model** - Task configuration with JSON serialization
  - Properties: `name`, `interval`, `isActive`, `isOneTime`, `registeredAt`, `alarmId`

### Changed

- Renamed `loopInterval` parameter to `interval` in `registerTask()` for clarity
- Updated README with comprehensive English documentation
- Clarified that hybrid approach has no minimum interval (only backup task has 15-min minimum)

## [1.0.0] - 2026-02-03

### Added

- Initial release of `hybrid_task_runner`
- `HybridRunner.initialize()` - Initialize AlarmManager and WorkManager plugins
- `HybridRunner.start()` - Start the hybrid task loop with configurable interval
- `HybridRunner.stop()` - Stop the task loop and cancel pending alarms/tasks
- `HybridRunner.isActive` - Check if runner is currently active
- `HybridRunner.loopInterval` - Get current loop interval
- `HybridStorage` - Utility for persisting callback handles and configuration
- Exported callbacks `alarmCallback` and `workmanagerCallbackDispatcher` for advanced use cases
- Comprehensive test suite with 29 tests
- Example application demonstrating usage
- Full documentation and README

### Architecture

- Uses `android_alarm_manager_plus` for precision scheduling
- Uses `workmanager` for reliable long-running task execution
- Uses `shared_preferences` for persisting callback handles across isolates
- Hybrid strategy: Alarm fires → Enqueues WorkManager → Executes task → Reschedules alarm
