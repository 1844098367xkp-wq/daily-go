import 'package:flutter/foundation.dart';

/// 任务生命周期状态枚举
enum TaskStatus {
  /// 待办（当天计划中）
  todo('TODO'),

  /// 已完成
  completed('COMPLETED'),

  /// 已顺延（延期至未来）
  postponed('POSTPONED'),

  /// 已归档/沉淀（移出主时间流）
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
  /// 单次不重复
  none('NONE'),

  /// 每天重复
  daily('DAILY'),

  /// 每个工作日重复 (周一至周五)
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
@immutable
class TaskModel {
  /// 唯一标识 (UUID v4 / NanoID)
  final String id;

  /// 任务标题（已清洗掉时间关键词）
  final String title;

  /// 原始自然语言输入文本（用于回溯或调试）
  final String? rawInput;

  /// 目标计划日期 (格式: YYYY-MM-DD，如 '2026-10-08')
  final String targetDate;

  /// 计划具体时刻 (格式: HH:mm，如 '14:30'，null 表示全天/随时处理)
  final String? timeSlot;

  /// 当前状态
  final TaskStatus status;

  /// 优先级标记 (0: 普通, 1: 聚焦/置顶，UI 默认不强制暴露)
  final int priority;

  /// 重复规则
  final RecurrenceRule recurrenceRule;

  /// 自定义手动排序权重
  final int sortOrder;

  /// 累计顺延次数（>=3 次提示拆解，>=7 次自动沉淀）
  final int rolloverCount;

  /// 完成时间戳（毫秒，用于 650ms 延时折叠及历史回溯）
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
    this.completedAt,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 是否为已完成状态
  bool get isCompleted => status == TaskStatus.completed;

  /// 是否为定点任务 (有具体时分点)
  bool get hasSpecificTime => timeSlot != null && timeSlot!.trim().isNotEmpty;

  /// 是否属于疲劳任务 (顺延次数过多)
  bool get isHighFatigue => rolloverCount >= 3;

  /// 复制并更新部分属性 (不可变对象更新模式)
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

/// 今日聚焦流多维加权排序比较器 (TaskComparator)
/// 排序规则：
/// 1. 完成状态：未完成在前，已完成沉底；
/// 2. 优先级置顶：priority 降序 (1 > 0)；
/// 3. 时间维度：有具体点位 (09:30) 排在前且按时钟升序，全天/随时排在后；
/// 4. 自定义排序：sort_order 升序；
/// 5. 创建时间：created_at 升序。
class TaskComparator {
  static int compare(TaskModel a, TaskModel b) {
    // 维度 1：完成状态权重 (未完成 = 0, 已完成 = 1)
    final aCompletedWeight = a.isCompleted ? 1 : 0;
    final bCompletedWeight = b.isCompleted ? 1 : 0;
    if (aCompletedWeight != bCompletedWeight) {
      return aCompletedWeight.compareTo(bCompletedWeight);
    }

    // 维度 2：优先级/置顶权重 (高优在前)
    if (a.priority != b.priority) {
      return b.priority.compareTo(a.priority);
    }

    // 维度 3：定点时间权重
    // 均有定点时间：按时间字符串字母序 (如 '09:30' < '14:00')
    if (a.hasSpecificTime && b.hasSpecificTime) {
      final timeCompare = a.timeSlot!.compareTo(b.timeSlot!);
      if (timeCompare != 0) return timeCompare;
    } else if (a.hasSpecificTime && !b.hasSpecificTime) {
      // a 有时间排在前面
      return -1;
    } else if (!a.hasSpecificTime && b.hasSpecificTime) {
      // b 有时间排在前面
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
