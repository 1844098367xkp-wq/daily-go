import 'package:flutter/foundation.dart';

/// 任务生命周期状态枚举
enum TaskStatus {
  /// 待办（计划中）
  todo('TODO'),

  /// 已完成
  completed('COMPLETED'),

  /// 已暂停（整条置灰半透明）
  paused('PAUSED'),

  /// 已顺延（延期至未来）
  postponed('POSTPONED'),

  /// 已归档/灵感箱（移出主时间流）
  archived('ARCHIVED');

  final String value;
  const TaskStatus(this.value);

  static TaskStatus fromString(String val) {
    return TaskStatus.values.firstWhere(
      (e) => e.value == val,
      orElse: () => TaskStatus.todo,
    );
  }
}

/// 基础重复规则枚举（轻量扩展）
enum RecurrenceRule {
  none('NONE'),
  daily('DAILY'),
  weekday('WEEKDAY');

  final String value;
  const RecurrenceRule(this.value);

  static RecurrenceRule fromString(String? val) {
    if (val == null) return RecurrenceRule.none;
    return RecurrenceRule.values.firstWhere(
      (e) => e.value == val,
      orElse: () => RecurrenceRule.none,
    );
  }
}

/// 《每日行》核心任务领域模型 (不可变实体)
/// 支持年月日、精确时分秒 (HH:mm:ss)、循环强闹钟与本地自定义音乐
@immutable
class TaskModel {
  /// 唯一标识 (UUID v4)
  final String id;

  /// 任务标题（已清洗掉时间关键词）
  final String title;

  /// 原始自然语言输入文本
  final String? rawInput;

  /// 目标计划日期 (格式: YYYY-MM-DD，如 '2026-10-08')
  final String targetDate;

  /// 计划具体时刻 (精确至秒: HH:mm:ss 或 HH:mm，如 '14:30:00'，null 表示全天/随时处理)
  final String? timeSlot;

  /// 当前状态
  final TaskStatus status;

  /// 优先级标记 (0: 普通, 1: 聚焦/置顶)
  final int priority;

  /// 重复规则
  final RecurrenceRule recurrenceRule;

  /// 自定义手动排序权重
  final int sortOrder;

  /// 累计顺延次数（>=3 次提示拆解，>=7 次自动沉淀）
  final int rolloverCount;

  /// 是否启用强力到点闹钟 (循环播放音乐直到手动关闭)
  final bool hasAlarm;

  /// 自定义本地音乐/铃声路径 (为 null 则使用默认音乐)
  final String? customSoundPath;

  /// 完成时间戳（毫秒）
  final int? completedAt;

  /// 归档时间戳（毫秒）
  final int? archivedAt;

  /// 创建时间戳（毫秒）
  final int createdAt;

  /// 最后更新时间戳（毫秒）
  final int updatedAt;

  const TaskModel({
    required this.id,
    required this.title,
    this.rawInput,
    required this.targetDate,
    this.timeSlot,
    this.status = TaskStatus.todo,
    this.priority = 0,
    this.recurrenceRule = RecurrenceRule.none,
    this.sortOrder = 0,
    this.rolloverCount = 0,
    this.hasAlarm = true,
    this.customSoundPath,
    this.completedAt,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == TaskStatus.completed;
  bool get isPaused => status == TaskStatus.paused;
  bool get hasSpecificTime => timeSlot != null && timeSlot!.trim().isNotEmpty;
  bool get isHighFatigue => rolloverCount >= 3;

  /// 复制并更新部分属性
  TaskModel copyWith({
    String? id,
    String? title,
    String? rawInput,
    String? targetDate,
    String? timeSlot,
    TaskStatus? status,
    int? priority,
    RecurrenceRule? recurrenceRule,
    int? sortOrder,
    int? rolloverCount,
    bool? hasAlarm,
    String? customSoundPath,
    int? completedAt,
    int? archivedAt,
    int? createdAt,
    int? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      rawInput: rawInput ?? this.rawInput,
      targetDate: targetDate ?? this.targetDate,
      timeSlot: timeSlot ?? this.timeSlot,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      sortOrder: sortOrder ?? this.sortOrder,
      rolloverCount: rolloverCount ?? this.rolloverCount,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      customSoundPath: customSoundPath ?? this.customSoundPath,
      completedAt: completedAt ?? this.completedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 转换为 SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'raw_input': rawInput,
      'target_date': targetDate,
      'time_slot': timeSlot,
      'status': status.value,
      'priority': priority,
      'recurrence_rule': recurrenceRule == RecurrenceRule.none ? null : recurrenceRule.value,
      'sort_order': sortOrder,
      'rollover_count': rolloverCount,
      'has_alarm': hasAlarm ? 1 : 0,
      'custom_sound_path': customSoundPath,
      'completed_at': completedAt,
      'archived_at': archivedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// 从 SQLite Map 还原领域实体
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      title: map['title'] as String,
      rawInput: map['raw_input'] as String?,
      targetDate: map['target_date'] as String,
      timeSlot: map['time_slot'] as String?,
      status: TaskStatus.fromString(map['status'] as String),
      priority: (map['priority'] as int?) ?? 0,
      recurrenceRule: RecurrenceRule.fromString(map['recurrence_rule'] as String?),
      sortOrder: (map['sort_order'] as int?) ?? 0,
      rolloverCount: (map['rollover_count'] as int?) ?? 0,
      hasAlarm: (map['has_alarm'] as int?) != 0,
      customSoundPath: map['custom_sound_path'] as String?,
      completedAt: map['completed_at'] as int?,
      archivedAt: map['archived_at'] as int?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => id.hashCode ^ updatedAt.hashCode;
}

/// 多维加权排序比较器 (TaskComparator)
/// 支持精确至秒的字母序时间排序 (如 '09:30:00' < '09:30:15' < '14:00:00')
class TaskComparator {
  static int compare(TaskModel a, TaskModel b) {
    // 维度 1：完成状态权重 (未完成优先)
    final aCompletedWeight = a.isCompleted ? 1 : 0;
    final bCompletedWeight = b.isCompleted ? 1 : 0;
    if (aCompletedWeight != bCompletedWeight) {
      return aCompletedWeight.compareTo(bCompletedWeight);
    }

    // 维度 2：优先级/置顶权重
    if (a.priority != b.priority) {
      return b.priority.compareTo(a.priority);
    }

    // 维度 3：定点时间权重 (按时分秒字典序升序)
    if (a.hasSpecificTime && b.hasSpecificTime) {
      final timeCompare = a.timeSlot!.compareTo(b.timeSlot!);
      if (timeCompare != 0) return timeCompare;
    } else if (a.hasSpecificTime && !b.hasSpecificTime) {
      return -1;
    } else if (!a.hasSpecificTime && b.hasSpecificTime) {
      return 1;
    }

    // 维度 4：自定义排序索引
    if (a.sortOrder != b.sortOrder) {
      return a.sortOrder.compareTo(b.sortOrder);
    }

    // 维度 5：兜底按创建时间
    return a.createdAt.compareTo(b.createdAt);
  }
}
