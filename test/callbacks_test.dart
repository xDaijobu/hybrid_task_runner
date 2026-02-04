import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PluginUtilities Callback Handle', () {
    test('should return handle for top-level function', () {
      // Top-level functions should return a valid handle
      final handle = PluginUtilities.getCallbackHandle(topLevelCallback);
      expect(handle, isNotNull);
      expect(handle!.toRawHandle(), isNonZero);
    });

    test('should return handle for static function', () {
      final handle =
          PluginUtilities.getCallbackHandle(TestClass.staticCallback);
      expect(handle, isNotNull);
      expect(handle!.toRawHandle(), isNonZero);
    });

    test('should return null for instance method', () {
      final instance = TestClass();
      // Instance methods should return null
      // Note: This test verifies the expected behavior
      final handle =
          PluginUtilities.getCallbackHandle(instance.instanceCallback);
      // Instance methods are NOT supported
      expect(handle, isNull);
    });

    test('should return null for lambda/closure', () {
      // Closures should return null
      Future<bool> closure() async {
        return true;
      }

      final handle = PluginUtilities.getCallbackHandle(closure);
      expect(handle, isNull);
    });

    test('callback handle round-trip should work', () {
      final originalHandle =
          PluginUtilities.getCallbackHandle(topLevelCallback);
      expect(originalHandle, isNotNull);

      // Convert to raw handle and back
      final rawHandle = originalHandle!.toRawHandle();
      final restoredHandle = CallbackHandle.fromRawHandle(rawHandle);

      expect(restoredHandle.toRawHandle(), rawHandle);

      // Get the callback from the restored handle
      final callback = PluginUtilities.getCallbackFromHandle(restoredHandle);
      expect(callback, isNotNull);
    });

    test('different functions should have different handles', () {
      final handle1 = PluginUtilities.getCallbackHandle(topLevelCallback);
      final handle2 =
          PluginUtilities.getCallbackHandle(anotherTopLevelCallback);

      expect(handle1, isNotNull);
      expect(handle2, isNotNull);
      expect(handle1!.toRawHandle(), isNot(handle2!.toRawHandle()));
    });

    test('same function should have same handle', () {
      final handle1 = PluginUtilities.getCallbackHandle(topLevelCallback);
      final handle2 = PluginUtilities.getCallbackHandle(topLevelCallback);

      expect(handle1, isNotNull);
      expect(handle2, isNotNull);
      expect(handle1!.toRawHandle(), handle2!.toRawHandle());
    });
  });
}

/// Top-level callback for testing - this is valid
@pragma('vm:entry-point')
Future<bool> topLevelCallback() async {
  return true;
}

/// Another top-level callback for testing
@pragma('vm:entry-point')
Future<bool> anotherTopLevelCallback() async {
  return false;
}

/// Test class with static and instance methods
class TestClass {
  /// Static callback - this is valid
  @pragma('vm:entry-point')
  static Future<bool> staticCallback() async {
    return true;
  }

  /// Instance method - this is NOT valid for background isolates
  Future<bool> instanceCallback() async {
    return true;
  }
}
