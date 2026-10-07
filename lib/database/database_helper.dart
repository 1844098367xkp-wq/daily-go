import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 本地 SQLite 数据库助手单例 (Local-First 核心存储底座)
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'daily_go_tasks.db';
  static const int _dbVersion = 1;
  static const String tableName = 'tasks';

  Database? _database;

  /// 获取数据库实例 (懒加载单例)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化并打开本地 SQLite 数据库
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    return await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  /// 创建数据表结构与核心查询优化复合索引
  Future<void> _onCreate(Database db, int version) async {
    // 1. 创建任务主表
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
        completed_at INTEGER,
        archived_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 2. 复合索引：针对“首屏秒开”优化 (日期 + 状态快速过滤)
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tasks_target_date_status 
      ON $tableName(target_date, status)
    ''');

    // 3. 辅助索引：针对历史沉淀库与生命周期扫描
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tasks_status 
      ON $tableName(status)
    ''');
  }

  /// 关闭数据库连接
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
