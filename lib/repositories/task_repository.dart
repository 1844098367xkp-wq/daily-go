import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/task_model.dart';

/// 任务仓储层抽象接口
abstract class ITaskRepository {
  Future<TaskModel> createTask(TaskModel task);
  Future<List<TaskModel>> getTasksForDate(String targetDate);
  Future<List<TaskModel>> getUnfinishedTasksBeforeDate(String date);
  Future<int> updateTask(TaskModel task);
  Future<int> deleteTask(String taskId);
  Future<void> toggleTaskCompletion(String taskId, bool isCompleted);
  Future<void> postponeTask(String taskId, String newTargetDate);
  Future<int> batchPostponeYesterdayTasks({
    required String beforeDate,
    required String todayDate,
  });
  Future<int> batchArchiveYesterdayTasks(String beforeDate);
  Future<List<TaskModel>> getArchivedTasks();
  Future<String> exportTasksAsJson();
  Future<int> importTasksFromJson(String jsonStr);
}

/// 任务管理仓储层核心实现 (Local-First 数据层)
class TaskRepository implements ITaskRepository {
  final DatabaseHelper _dbHelper;

  TaskRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// 1. 新建任务
  @override
  Future<TaskModel> createTask(TaskModel task) async {
    final db = await _dbHelper.database;
    await db.insert(
      DatabaseHelper.tableName,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return task;
  }

  /// 2. 获取指定日期的任务列表（已应用今日聚焦流加权排序规则）
  @override
  Future<List<TaskModel>> getTasksForDate(String targetDate) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableName,
      where: 'target_date = ? AND status != ?',
      whereArgs: [targetDate, TaskStatus.archived.value],
    );

    final tasks = maps.map((map) => TaskModel.fromMap(map)).toList();

    // 核心：应用 TaskComparator 排序（未完成优先、有时钟点升序、无时钟点靠后）
    tasks.sort(TaskComparator.compare);
    return tasks;
  }

  /// 3. 查询指定日期之前的未完成事项（用于晨间 04:00 结算卡片检测）
  @override
  Future<List<TaskModel>> getUnfinishedTasksBeforeDate(String date) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableName,
      where: 'target_date < ? AND status = ?',
      whereArgs: [date, TaskStatus.todo.value],
      orderBy: 'target_date DESC, created_at ASC',
    );

    return maps.map((map) => TaskModel.fromMap(map)).toList();
  }

  /// 4. 更新单条任务信息
  @override
  Future<int> updateTask(TaskModel task) async {
    final db = await _dbHelper.database;
    final updatedTask = task.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    return await db.update(
      DatabaseHelper.tableName,
      updatedTask.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  /// 5. 切换任务完成状态 (带 650ms 撤销机制所需的时间戳记录)
  @override
  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      DatabaseHelper.tableName,
      {
        'status': isCompleted ? TaskStatus.completed.value : TaskStatus.todo.value,
        'completed_at': isCompleted ? now : null,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// 6. 单任务顺延（包含疲劳度防堆积：>=7次顺延自动转入沉淀箱）
  @override
  Future<void> postponeTask(String taskId, String newTargetDate) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 先查出当前任务以累加 rollover_count
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableName,
      columns: ['rollover_count'],
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );

    if (maps.isEmpty) return;

    final currentCount = (maps.first['rollover_count'] as int?) ?? 0;
    final newCount = currentCount + 1;

    // 防堆积规则：若连续顺延 7 次以上，自动沉淀入归档箱，防止污染主时间流
    if (newCount >= 7) {
      await db.update(
        DatabaseHelper.tableName,
        {
          'status': TaskStatus.archived.value,
          'rollover_count': newCount,
          'archived_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );
    } else {
      await db.update(
        DatabaseHelper.tableName,
        {
          'target_date': newTargetDate,
          'status': TaskStatus.todo.value,
          'rollover_count': newCount,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );
    }
  }

  /// 7. 晨间温和结算：一键全部顺延至今天 (使用 SQLite 事务原子执行)
  @override
  Future<int> batchPostponeYesterdayTasks({
    required String beforeDate,
    required String todayDate,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.transaction<int>((txn) async {
      // 1. 查询所有需顺延的任务
      final List<Map<String, dynamic>> pendingTasks = await txn.query(
        DatabaseHelper.tableName,
        columns: ['id', 'rollover_count'],
        where: 'target_date < ? AND status = ?',
        whereArgs: [beforeDate, TaskStatus.todo.value],
      );

      if (pendingTasks.isEmpty) return 0;

      int updatedCount = 0;
      for (final task in pendingTasks) {
        final id = task['id'] as String;
        final count = ((task['rollover_count'] as int?) ?? 0) + 1;

        if (count >= 7) {
          // 超过阈值自动沉淀
          await txn.update(
            DatabaseHelper.tableName,
            {
              'status': TaskStatus.archived.value,
              'rollover_count': count,
              'archived_at': now,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          // 顺延至今天
          await txn.update(
            DatabaseHelper.tableName,
            {
              'target_date': todayDate,
              'status': TaskStatus.todo.value,
              'rollover_count': count,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        updatedCount++;
      }
      return updatedCount;
    });
  }

  /// 8. 晨间温和结算：一键将昨日余项移入沉淀箱
  @override
  Future<int> batchArchiveYesterdayTasks(String beforeDate) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.update(
      DatabaseHelper.tableName,
      {
        'status': TaskStatus.archived.value,
        'archived_at': now,
        'updated_at': now,
      },
      where: 'target_date < ? AND status = ?',
      whereArgs: [beforeDate, TaskStatus.todo.value],
    );
  }

  /// 9. 物理删除任务
  @override
  Future<int> deleteTask(String taskId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      DatabaseHelper.tableName,
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// 10. 获取沉淀箱历史列表
  @override
  Future<List<TaskModel>> getArchivedTasks() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableName,
      where: 'status = ?',
      whereArgs: [TaskStatus.archived.value],
      orderBy: 'archived_at DESC, updated_at DESC',
    );

    return maps.map((map) => TaskModel.fromMap(map)).toList();
  }

  /// 11. 本地免联网数据导出 (JSON 格式备份)
  @override
  Future<String> exportTasksAsJson() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> allTasks = await db.query(
      DatabaseHelper.tableName,
      orderBy: 'created_at ASC',
    );
    return jsonEncode({
      'app': 'DailyGo',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'tasks': allTasks,
    });
  }

  /// 12. 本地免联网数据导入恢复
  @override
  Future<int> importTasksFromJson(String jsonStr) async {
    final db = await _dbHelper.database;
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final tasks = (data['tasks'] as List<dynamic>?) ?? [];

    return await db.transaction<int>((txn) async {
      int imported = 0;
      for (final item in tasks) {
        final taskMap = Map<String, dynamic>.from(item as Map);
        await txn.insert(
          DatabaseHelper.tableName,
          taskMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        imported++;
      }
      return imported;
    });
  }
}
