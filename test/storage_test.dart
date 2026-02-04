import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_task_runner/src/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Clear SharedPreferences before each test
    SharedPreferences.setMockInitialValues({});
  });

  group('HybridStorage', () {
    group('Callback Handle', () {
      test('should store and retrieve callback handle', () async {
        // Create a mock callback handle
        const rawHandle = 123456789;
        final handle = CallbackHandle.fromRawHandle(rawHandle);

        await HybridStorage.storeCallbackHandle(handle);
        final retrieved = await HybridStorage.getCallbackHandle();

        expect(retrieved, isNotNull);
        expect(retrieved!.toRawHandle(), rawHandle);
      });

      test('should return null when no handle is stored', () async {
        final retrieved = await HybridStorage.getCallbackHandle();
        expect(retrieved, isNull);
      });
    });

    group('Loop Interval', () {
      test('should store and retrieve loop interval', () async {
        const interval = Duration(minutes: 15);

        await HybridStorage.storeLoopInterval(interval);
        final retrieved = await HybridStorage.getLoopInterval();

        expect(retrieved, isNotNull);
        expect(retrieved, interval);
      });

      test('should handle various durations', () async {
        final testCases = [
          const Duration(seconds: 30),
          const Duration(minutes: 1),
          const Duration(hours: 1),
          const Duration(days: 1),
        ];

        for (final duration in testCases) {
          await HybridStorage.storeLoopInterval(duration);
          final retrieved = await HybridStorage.getLoopInterval();

          expect(retrieved, isNotNull, reason: 'Duration: $duration');
          expect(retrieved, duration, reason: 'Duration: $duration');
        }
      });

      test('should return null when no interval is stored', () async {
        final retrieved = await HybridStorage.getLoopInterval();
        expect(retrieved, isNull);
      });
    });

    group('Active Status', () {
      test('should store and retrieve active status (true)', () async {
        await HybridStorage.setActive(true);
        final isActive = await HybridStorage.isActive();

        expect(isActive, isTrue);
      });

      test('should store and retrieve active status (false)', () async {
        await HybridStorage.setActive(false);
        final isActive = await HybridStorage.isActive();

        expect(isActive, isFalse);
      });

      test('should default to false when not set', () async {
        final isActive = await HybridStorage.isActive();
        expect(isActive, isFalse);
      });

      test('should toggle active status correctly', () async {
        await HybridStorage.setActive(true);
        expect(await HybridStorage.isActive(), isTrue);

        await HybridStorage.setActive(false);
        expect(await HybridStorage.isActive(), isFalse);

        await HybridStorage.setActive(true);
        expect(await HybridStorage.isActive(), isTrue);
      });
    });

    group('Clear', () {
      test('should clear all stored data', () async {
        // Store some data
        const rawHandle = 123456789;
        final handle = CallbackHandle.fromRawHandle(rawHandle);
        await HybridStorage.storeCallbackHandle(handle);
        await HybridStorage.storeLoopInterval(const Duration(minutes: 15));
        await HybridStorage.setActive(true);

        // Verify data is stored
        expect(await HybridStorage.getCallbackHandle(), isNotNull);
        expect(await HybridStorage.getLoopInterval(), isNotNull);
        expect(await HybridStorage.isActive(), isTrue);

        // Clear all data
        await HybridStorage.clear();

        // Verify all data is cleared
        expect(await HybridStorage.getCallbackHandle(), isNull);
        expect(await HybridStorage.getLoopInterval(), isNull);
        expect(await HybridStorage.isActive(), isFalse);
      });
    });
  });
}
