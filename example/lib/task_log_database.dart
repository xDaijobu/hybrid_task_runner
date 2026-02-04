import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// A log entry representing a task execution event.
class TaskLog {
  final int? id;
  final DateTime timestamp;
  final String event;
  final String message;
  final bool success;
  final bool isBackground;

  TaskLog({
    this.id,
    required this.timestamp,
    required this.event,
    required this.message,
    required this.success,
    this.isBackground = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'event': event,
      'message': message,
      'success': success ? 1 : 0,
      'is_background': isBackground ? 1 : 0,
    };
  }

  factory TaskLog.fromMap(Map<String, dynamic> map) {
    return TaskLog(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      event: map['event'] as String,
      message: map['message'] as String,
      success: (map['success'] as int) == 1,
      isBackground: (map['is_background'] as int?) == 1,
    );
  }
}

/// Database helper for storing task execution logs.
class TaskLogDatabase {
  static Database? _database;
  static const String _tableName = 'task_logs';
  static const int _dbVersion = 2; // Upgraded for new column

  /// Get the database instance (singleton).
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'task_logs.db');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            event TEXT NOT NULL,
            message TEXT NOT NULL,
            success INTEGER NOT NULL,
            is_background INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN is_background INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  /// Insert a new log entry.
  static Future<int> insert(TaskLog log) async {
    final db = await database;
    return await db.insert(_tableName, log.toMap());
  }

  /// Get all logs, ordered by timestamp descending.
  static Future<List<TaskLog>> getAll() async {
    final db = await database;
    final maps = await db.query(_tableName, orderBy: 'timestamp DESC');
    return maps.map((map) => TaskLog.fromMap(map)).toList();
  }

  /// Get the most recent N logs.
  static Future<List<TaskLog>> getRecent(int limit) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((map) => TaskLog.fromMap(map)).toList();
  }

  /// Clear all logs.
  static Future<int> clear() async {
    final db = await database;
    return await db.delete(_tableName);
  }

  /// Get the count of logs.
  static Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
