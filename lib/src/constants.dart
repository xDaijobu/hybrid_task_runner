/// Constants used across the hybrid_task_runner package.
library;

/// SharedPreferences key for storing the user's callback handle (legacy).
const String kCallbackHandleKey = 'hybrid_task_runner_callback_handle';

/// SharedPreferences key for storing the loop interval in milliseconds (legacy).
const String kLoopIntervalKey = 'hybrid_task_runner_loop_interval';

/// SharedPreferences key for storing the active status (legacy).
const String kActiveStatusKey = 'hybrid_task_runner_active';

/// SharedPreferences key for storing the task overlap policy (legacy).
const String kTaskOverlapPolicyKey = 'hybrid_task_runner_overlap_policy';

/// SharedPreferences key for storing all registered tasks as JSON.
const String kRegisteredTasksKey = 'hybrid_task_runner_registered_tasks';

/// SharedPreferences key for the next alarm ID counter.
const String kNextAlarmIdKey = 'hybrid_task_runner_next_alarm_id';

/// The base alarm ID used for scheduling alarms.
/// Each task gets a unique ID starting from this base.
const int kBaseAlarmId = 10000;

/// The legacy alarm ID (for backward compatibility).
const int kAlarmId = 9999;

/// The unique name for the WorkManager task.
const String kWorkManagerTaskName = 'hybridTask';

/// The unique tag for the WorkManager task.
const String kWorkManagerTaskTag = 'hybrid_task_runner_tag';
