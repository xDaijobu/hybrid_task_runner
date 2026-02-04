import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'registered_task.dart';

/// Storage utility for persisting callback handles and configuration.
///
/// Uses SharedPreferences to store data that needs to survive app restarts
/// and be accessible from background isolates.
class HybridStorage {
  HybridStorage._();

  // ============================================
  // Legacy single-task methods (backward compatibility)
  // ============================================

  /// Stores the callback handle for the user's task function.
  ///
  /// The callback handle is an integer representation of a function pointer
  /// that can be used to invoke the function from a different isolate.
  static Future<void> storeCallbackHandle(CallbackHandle handle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kCallbackHandleKey, handle.toRawHandle());
  }

  /// Retrieves the stored callback handle.
  ///
  /// Returns null if no callback handle has been stored.
  static Future<CallbackHandle?> getCallbackHandle() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHandle = prefs.getInt(kCallbackHandleKey);
    if (rawHandle == null) return null;
    return CallbackHandle.fromRawHandle(rawHandle);
  }

  /// Stores the loop interval in milliseconds.
  static Future<void> storeLoopInterval(Duration interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kLoopIntervalKey, interval.inMilliseconds);
  }

  /// Retrieves the stored loop interval.
  ///
  /// Returns null if no interval has been stored.
  static Future<Duration?> getLoopInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final milliseconds = prefs.getInt(kLoopIntervalKey);
    if (milliseconds == null) return null;
    return Duration(milliseconds: milliseconds);
  }

  /// Stores the active status of the hybrid runner.
  static Future<void> setActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kActiveStatusKey, active);
  }

  /// Retrieves the active status of the hybrid runner.
  ///
  /// Returns false if no status has been stored.
  static Future<bool> isActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kActiveStatusKey) ?? false;
  }

  /// Stores the task overlap policy as an integer (enum index).
  static Future<void> storeTaskOverlapPolicy(int policyIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kTaskOverlapPolicyKey, policyIndex);
  }

  /// Retrieves the stored task overlap policy index.
  ///
  /// Returns 0 (replace) as default if no policy has been stored.
  static Future<int> getTaskOverlapPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(kTaskOverlapPolicyKey) ?? 0; // default: replace
  }

  // ============================================
  // Multi-task storage methods
  // ============================================

  /// Saves a registered task to storage.
  /// If a task with the same name exists, it will be replaced.
  static Future<void> saveTask(RegisteredTask task) async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = await getAllTasks();

    // Remove existing task with same name if exists
    tasks.removeWhere((t) => t.name == task.name);
    tasks.add(task);

    // Convert to JSON list
    final jsonList = tasks.map((t) => t.toJson()).toList();
    await prefs.setString(kRegisteredTasksKey, jsonEncode(jsonList));
  }

  /// Gets a specific task by name.
  /// Returns null if not found.
  static Future<RegisteredTask?> getTask(String name) async {
    final tasks = await getAllTasks();
    try {
      return tasks.firstWhere((t) => t.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Gets a task by its alarm ID.
  /// Returns null if not found.
  static Future<RegisteredTask?> getTaskByAlarmId(int alarmId) async {
    final tasks = await getAllTasks();
    try {
      return tasks.firstWhere((t) => t.alarmId == alarmId);
    } catch (_) {
      return null;
    }
  }

  /// Gets all registered tasks.
  static Future<List<RegisteredTask>> getAllTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(kRegisteredTasksKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => RegisteredTask.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Removes a specific task by name.
  /// Returns true if task was found and removed.
  static Future<bool> removeTask(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = await getAllTasks();

    final lengthBefore = tasks.length;
    tasks.removeWhere((t) => t.name == name);

    if (tasks.length == lengthBefore) {
      return false; // Task not found
    }

    // Save updated list
    final jsonList = tasks.map((t) => t.toJson()).toList();
    await prefs.setString(kRegisteredTasksKey, jsonEncode(jsonList));
    return true;
  }

  /// Updates a task's active status.
  static Future<void> setTaskActive(String name, bool active) async {
    final task = await getTask(name);
    if (task != null) {
      await saveTask(task.copyWith(isActive: active));
    }
  }

  /// Gets the next available alarm ID and increments the counter.
  static Future<int> getNextAlarmId() async {
    final prefs = await SharedPreferences.getInstance();
    final currentId = prefs.getInt(kNextAlarmIdKey) ?? kBaseAlarmId;
    await prefs.setInt(kNextAlarmIdKey, currentId + 1);
    return currentId;
  }

  /// Clears legacy single-task data.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kCallbackHandleKey);
    await prefs.remove(kLoopIntervalKey);
    await prefs.remove(kActiveStatusKey);
    await prefs.remove(kTaskOverlapPolicyKey);
  }

  /// Clears ALL stored data including all registered tasks.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kCallbackHandleKey);
    await prefs.remove(kLoopIntervalKey);
    await prefs.remove(kActiveStatusKey);
    await prefs.remove(kTaskOverlapPolicyKey);
    await prefs.remove(kRegisteredTasksKey);
    await prefs.remove(kNextAlarmIdKey);
  }
}
