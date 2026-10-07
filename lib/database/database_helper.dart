import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 本地 SQLite 数据库助手单例 (Local-First 核心存储底座)
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'daily_go_tasks.db';
  static const int _dbVersion = 2; // 升级版本至 2
  static const String tableName = 'tasks';

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

    // 2. 核心复合索引
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
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
