/// Represents a registered background task with its configuration.
class RegisteredTask {
  /// Unique name/identifier for this task.
  final String name;

  /// The raw callback handle stored as an integer.
  final int callbackHandle;

  /// The interval between task executions in milliseconds.
  /// For one-time tasks, this is the delay before execution.
  final int intervalMs;

  /// The task overlap policy index (0=replace, 1=skipIfRunning, 2=parallel).
  final int overlapPolicyIndex;

  /// Whether this task is currently active.
  final bool isActive;

  /// The alarm ID assigned to this task.
  final int alarmId;

  /// When this task was registered.
  final DateTime registeredAt;

  /// Whether this task should only run once.
  /// If true, the task will be removed after execution.
  final bool isOneTime;

  RegisteredTask({
    required this.name,
    required this.callbackHandle,
    required this.intervalMs,
    required this.overlapPolicyIndex,
    required this.isActive,
    required this.alarmId,
    required this.registeredAt,
    this.isOneTime = false,
  });

  /// Creates a RegisteredTask from a JSON map.
  factory RegisteredTask.fromJson(Map<String, dynamic> json) {
    return RegisteredTask(
      name: json['name'] as String,
      callbackHandle: json['callbackHandle'] as int,
      intervalMs: json['intervalMs'] as int,
      overlapPolicyIndex: json['overlapPolicyIndex'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      alarmId: json['alarmId'] as int,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      isOneTime: json['isOneTime'] as bool? ?? false,
    );
  }

  /// Converts this RegisteredTask to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'callbackHandle': callbackHandle,
      'intervalMs': intervalMs,
      'overlapPolicyIndex': overlapPolicyIndex,
      'isActive': isActive,
      'alarmId': alarmId,
      'registeredAt': registeredAt.toIso8601String(),
      'isOneTime': isOneTime,
    };
  }

  /// Returns the interval as a Duration.
  Duration get interval => Duration(milliseconds: intervalMs);

  /// Creates a copy with updated fields.
  RegisteredTask copyWith({
    String? name,
    int? callbackHandle,
    int? intervalMs,
    int? overlapPolicyIndex,
    bool? isActive,
    int? alarmId,
    DateTime? registeredAt,
    bool? isOneTime,
  }) {
    return RegisteredTask(
      name: name ?? this.name,
      callbackHandle: callbackHandle ?? this.callbackHandle,
      intervalMs: intervalMs ?? this.intervalMs,
      overlapPolicyIndex: overlapPolicyIndex ?? this.overlapPolicyIndex,
      isActive: isActive ?? this.isActive,
      alarmId: alarmId ?? this.alarmId,
      registeredAt: registeredAt ?? this.registeredAt,
      isOneTime: isOneTime ?? this.isOneTime,
    );
  }

  @override
  String toString() {
    final type = isOneTime ? 'one-time' : 'loop';
    return 'RegisteredTask(name: $name, interval: ${interval.inMinutes}min, type: $type, active: $isActive)';
  }
}
