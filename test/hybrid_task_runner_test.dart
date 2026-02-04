import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_task_runner/hybrid_task_runner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Mock SharedPreferences for all tests
    SharedPreferences.setMockInitialValues({});
  });

  group('Constants', () {
    test('kCallbackHandleKey should be defined', () {
      expect(kCallbackHandleKey, isNotEmpty);
      expect(kCallbackHandleKey, 'hybrid_task_runner_callback_handle');
    });

    test('kLoopIntervalKey should be defined', () {
      expect(kLoopIntervalKey, isNotEmpty);
      expect(kLoopIntervalKey, 'hybrid_task_runner_loop_interval');
    });

    test('kActiveStatusKey should be defined', () {
      expect(kActiveStatusKey, isNotEmpty);
      expect(kActiveStatusKey, 'hybrid_task_runner_active');
    });

    test('kAlarmId should be a reasonable value', () {
      expect(kAlarmId, isPositive);
      expect(kAlarmId, 9999);
    });

    test('kWorkManagerTaskName should be defined', () {
      expect(kWorkManagerTaskName, isNotEmpty);
      expect(kWorkManagerTaskName, 'hybridTask');
    });

    test('kWorkManagerTaskTag should be defined', () {
      expect(kWorkManagerTaskTag, isNotEmpty);
      expect(kWorkManagerTaskTag, 'hybrid_task_runner_tag');
    });
  });

  group('HybridRunner', () {
    test('isActive should return false when not started', () async {
      final isActive = await HybridRunner.isActive;
      expect(isActive, isFalse);
    });

    test('loopInterval should return null when not set', () async {
      final interval = await HybridRunner.loopInterval;
      expect(interval, isNull);
    });
  });

  group('HybridTaskCallback', () {
    test('typedef should accept valid function', () {
      // Define a valid callback matching the HybridTaskCallback signature
      Future<bool> validCallback() async {
        return true;
      }

      // This should compile and pass type check
      final HybridTaskCallback callback = validCallback;
      expect(callback, isA<HybridTaskCallback>());
    });
  });

  group('Exported symbols', () {
    test('alarmCallback should be exported', () {
      // Just verify the function is accessible (exported)
      expect(alarmCallback, isA<Function>());
    });

    test('workmanagerCallbackDispatcher should be exported', () {
      expect(workmanagerCallbackDispatcher, isA<Function>());
    });

    test('HybridStorage should be exported', () {
      expect(HybridStorage, isNotNull);
    });
  });
}
