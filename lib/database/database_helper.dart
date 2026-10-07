import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 本地 SQLite 数据库助手单例 (Local-First 核心存储底座)
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'daily_go_tasks.db';
  static const int _dbVersion = 3; // 升级版本至 3 (增加 app_settings 表)
  static const String tableName = 'tasks';
  static const String settingsTable = 'app_settings';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    return await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. 创建任务主表 (支持精确时分秒、强闹钟与自定义音乐路径)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        raw_input TEXT,
        target_date TEXT NOT NULL,
        time_slot TEXT,
        status TEXT NOT NULL DEFAULT 'TODO',
        priority INTEGER NOT NULL DEFAULT 0,
        recurrence_rule TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        rollover_count INTEGER NOT NULL DEFAULT 0,
        has_alarm INTEGER NOT NULL DEFAULT 1,
        custom_sound_path TEXT,
        completed_at INTEGER,
        archived_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 2. 创建通用配置表 (持久化自定义背景图片等设置)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $settingsTable (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT
      )
    ''');

    // 3. 核心复合索引
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tasks_target_date_status 
      ON $tableName(target_date, status)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tasks_status 
      ON $tableName(status)
    ''');
  }

  /// 平滑迁移升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE $tableName ADD COLUMN has_alarm INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $tableName ADD COLUMN custom_sound_path TEXT');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $settingsTable (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT
          )
        ''');
      } catch (_) {}
    }
  }

  Future<void> setSetting(String key, String? value) async {
    final db = await database;
    if (value == null) {
      await db.delete(settingsTable, where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert(
        settingsTable,
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    try {
      final res = await db.query(
        settingsTable,
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (res.isNotEmpty) {
        return res.first['value'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
