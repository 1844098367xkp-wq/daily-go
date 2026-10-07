import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../repositories/task_repository.dart';
import '../services/time_parser_service.dart';
import '../theme/app_theme.dart';
import '../widgets/task_item_widget.dart';
import '../widgets/rollover_card_widget.dart';
import '../widgets/quick_capture_bottom_sheet.dart';
import '../widgets/date_timeline_strip.dart';
import '../widgets/alarm_dialog_widget.dart';
import 'idea_inbox_screen.dart';

/// 全局日程表主页面 (极美高质感重构)
/// 彻底告别“首页空白”与“生硬图标”，重构沉淀箱为【灵感备忘与成就足迹】
class TodayScreen extends StatefulWidget {
  final TaskRepository repository;

  const TodayScreen({
    super.key,
    required this.repository,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late String _selectedDate; // 当前选中的查看日期 YYYY-MM-DD
  late String _realTodayStr; // 真实的今天日期 YYYY-MM-DD

  List<TaskModel> _currentDateTasks = [];
  List<TaskModel> _yesterdayPendingTasks = [];
  Set<String> _datesWithTasks = {};
  bool _isLoading = true;

  Timer? _alarmCheckTimer;
  final Set<String> _triggeredAlarmTaskIds = {};

  @override
  void initState() {
    super.initState();
    _realTodayStr = TimeParserService.formatDate(DateTime.now());
    _selectedDate = _realTodayStr;

    _loadData();
    _startAlarmDaemon();
  }

  @override
  void dispose() {
    _alarmCheckTimer?.cancel();
    super.dispose();
  }

  void _startAlarmDaemon() {
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkAndTriggerAlarms();
    });
  }

  Future<void> _checkAndTriggerAlarms() async {
    final now = DateTime.now();
    final todayStr = TimeParserService.formatDate(now);
    final nowTimeStr = TimeParserService.formatTime(now.hour, now.minute, now.second);
    final nowShortTimeStr = TimeParserService.formatTime(now.hour, now.minute);

    for (final task in _currentDateTasks) {
      if (task.targetDate == todayStr &&
          !task.isCompleted &&
          task.hasAlarm &&
          task.timeSlot != null &&
          !_triggeredAlarmTaskIds.contains(task.id)) {
        final taskTime = task.timeSlot!;
        final isMatch = (taskTime == nowTimeStr) ||
            (taskTime.length == 5 && nowShortTimeStr == taskTime && now.second == 0);

        if (isMatch) {
          _triggeredAlarmTaskIds.add(task.id);
          _popAlarmDialog(task);
          break;
        }
      }
    }
  }

  void _popAlarmDialog(TaskModel task) {
    if (!mounted) return;
    AlarmDialogWidget.show(
      context,
      task: task,
      onDismiss: () {},
      onSnooze: () {
        Timer(const Duration(minutes: 5), () {
          _triggeredAlarmTaskIds.remove(task.id);
        });
      },
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final tasks = await widget.repository.getTasksForDate(_selectedDate);
    final yesterdayPending = await widget.repository.getUnfinishedTasksBeforeDate(_realTodayStr);

    final datesSet = <String>{_selectedDate};
    if (yesterdayPending.isNotEmpty) {
      datesSet.add(yesterdayPending.first.targetDate);
    }

    if (mounted) {
      setState(() {
        _currentDateTasks = tasks;
        _yesterdayPendingTasks = yesterdayPending;
        _datesWithTasks = datesSet;
        _isLoading = false;
      });
    }
  }

  void _handleDateChanged(String newDate) {
    if (_selectedDate == newDate) return;
    setState(() => _selectedDate = newDate);
    _loadData();
  }

  /// 滑动手势切换日期：向右顺划 +1 天，左滑 -1 天
  void _shiftDate(int dayDelta) {
    try {
      final parts = _selectedDate.split('-');
      final current = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final target = current.add(Duration(days: dayDelta));
      final newDateStr = TimeParserService.formatDate(target);
      _handleDateChanged(newDateStr);
    } catch (_) {}
  }

  Future<void> _handleBatchPostpone() async {
    await widget.repository.batchPostponeYesterdayTasks(
      beforeDate: _realTodayStr,
      todayDate: _realTodayStr,
    );
    await _loadData();
  }

  Future<void> _handleBatchArchive() async {
    await widget.repository.batchArchiveYesterdayTasks(_realTodayStr);
    await _loadData();
  }

  Future<void> _handleCreateTask(
    String title,
    String targetDate,
    String? timeSlot,
    String rawInput,
    bool hasAlarm,
    String? customSoundPath,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newTask = TaskModel(
      id: const Uuid().v4(),
      title: title,
      rawInput: rawInput,
      targetDate: targetDate,
      timeSlot: timeSlot,
      status: TaskStatus.todo,
      hasAlarm: hasAlarm,
      customSoundPath: customSoundPath,
      createdAt: now,
      updatedAt: now,
    );

    await widget.repository.createTask(newTask);

    if (targetDate == _selectedDate) {
      await _loadData();
    } else {
      setState(() => _selectedDate = targetDate);
      await _loadData();
    }
  }

  Future<void> _handleToggleComplete(String taskId, bool isCompleted) async {
    await widget.repository.toggleTaskCompletion(taskId, isCompleted);
    final updated = await widget.repository.getTasksForDate(_selectedDate);
    if (mounted) {
      setState(() => _currentDateTasks = updated);
    }
  }

  Future<void> _handleTogglePause(String taskId, bool isPaused) async {
    final taskIndex = _currentDateTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;
    final task = _currentDateTasks[taskIndex];
    final updated = task.copyWith(
      status: isPaused ? TaskStatus.paused : TaskStatus.todo,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await widget.repository.updateTask(updated);
    await _loadData();
  }

  Future<void> _handleDeleteTask(String taskId) async {
    await widget.repository.deleteTask(taskId);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryTextColor = AppTheme.textSecondaryLight;
    final cardColor = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final primaryColor = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;

    final timedTasks = _currentDateTasks.where((t) => t.hasSpecificTime).toList();
    final anytimeTasks = _currentDateTasks.where((t) => !t.hasSpecificTime).toList();
    final totalCount = _currentDateTasks.length;
    final completedCount = _currentDateTasks.where((t) => t.isCompleted).length;
    final activeCount = totalCount - completedCount;
    final isViewingToday = _selectedDate == _realTodayStr;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // 1. 顶部日期横向滑动胶囊轴 (定位任意一天)
            DateTimelineStrip(
              selectedDate: _selectedDate,
              onSelectDate: _handleDateChanged,
              datesWithTasks: _datesWithTasks,
            ),

            // 2. 状态主头部栏：日期、回到今天与重塑后的【灵感备忘箱】
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.spacing20,
                right: AppTheme.spacing20,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatSelectedDisplayDate(_selectedDate),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: primaryTextColor,
                        ),
                      ),
                      if (!isViewingToday) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _handleDateChanged(_realTodayStr),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_rounded, size: 12, color: primaryColor),
                                const SizedBox(width: 2),
                                Text(
                                  '今天',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // 焕新图标：灵感备忘箱独立页面入口 (带紫罗兰优雅微底色)
                  GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => IdeaInboxScreen(repository: widget.repository),
                        ),
                      );
                      _loadData();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.badgeIdeaBgDark : AppTheme.badgeIdeaBgLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lightbulb_rounded,
                            size: 16,
                            color: isDark ? AppTheme.badgeIdeaDark : AppTheme.badgeIdeaLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '灵感箱',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.badgeIdeaDark : AppTheme.badgeIdeaLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. 核心流展示区 (向右顺划日期后移一天，左滑前移一天)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  final vel = details.primaryVelocity ?? 0;
                  if (vel > 200) {
                    // 向右顺划 -> 选中的日期向后移一天 (+1)
                    _shiftDate(1);
                  } else if (vel < -200) {
                    // 左滑 -> 向前移一天 (-1)
                    _shiftDate(-1);
                  }
                },
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator.adaptive())
                    : RefreshIndicator(
                        onRefresh: () async => _loadData(),
                        child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.only(bottom: 80),
                        children: [
                          // 3.1 今日心流节奏看板 (彻底击碎空白感)
                          _buildRhythmCard(
                            isDark,
                            totalCount,
                            completedCount,
                            activeCount,
                            isViewingToday,
                          ),

                          // 3.2 晨间温和结算卡片
                          if (isViewingToday && _yesterdayPendingTasks.isNotEmpty)
                            RolloverCardWidget(
                              pendingCount: _yesterdayPendingTasks.length,
                              onBatchPostpone: _handleBatchPostpone,
                              onBatchArchive: _handleBatchArchive,
                            ),

                          // 3.3 空状态或时间流列表
                          if (_currentDateTasks.isEmpty)
                            _buildAestheticEmptyState(isDark)
                          else ...[
                            // 分组 1: 具体时钟点 (带左侧垂直时间轴光柱连接线)
                            if (timedTasks.isNotEmpty) ...[
                              _buildTimelineSectionHeader(
                                '精确时刻安排 (${timedTasks.length})',
                                Icons.access_time_filled_rounded,
                                isDark ? AppTheme.badgeTimeDark : AppTheme.badgeTimeLight,
                              ),
                              _buildTaskGroup(timedTasks, cardColor, isDark),
                              const SizedBox(height: AppTheme.spacing20),
                            ],

                            // 分组 2: 随时处理 (无具体时间)
                            if (anytimeTasks.isNotEmpty) ...[
                              _buildTimelineSectionHeader(
                                '全天 / 随时从容推进 (${anytimeTasks.length})',
                                Icons.all_inclusive_rounded,
                                isDark ? AppTheme.badgeIdeaDark : AppTheme.badgeIdeaLight,
                              ),
                              _buildTaskGroup(anytimeTasks, cardColor, isDark),
                            ],
                          ],
                        ],
                      ),
                    ),
              ),
            ),

            // 4. 底部微质感录入悬浮唤起栏
            _buildBottomCaptureBar(context, isDark),
          ],
        ),
      ),
    );
  }

  /// 今日心流节奏微看板卡片 (视觉重心，告别空白)
  Widget _buildRhythmCard(
    bool isDark,
    int total,
    int completed,
    int active,
    bool isToday,
  ) {
    final progress = total > 0 ? (completed / total) : 0.0;
    final greeting = _getGreetingMessage();
    final primaryColor = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;
    final cardBg = isDark ? const Color(0xFF131B2E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(
        left: AppTheme.spacing20,
        right: AppTheme.spacing20,
        top: 4,
        bottom: 16,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow(isDark),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 环形进度圈
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4.5,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0
                        ? (isDark ? AppTheme.badgeSuccessDark : AppTheme.badgeSuccessLight)
                        : primaryColor,
                  ),
                ),
                Text(
                  total > 0 ? '${(progress * 100).toInt()}%' : '0%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? greeting : '规划日程',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  total > 0
                      ? '已完成 $completed 项 · 尚余 $active 项待专注'
                      : '从容无待办，正是开启新专注的时刻',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSectionHeader(String title, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacing20,
        right: AppTheme.spacing20,
        bottom: 10,
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskGroup(List<TaskModel> tasks, Color cardColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow(isDark),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < tasks.length; i++) ...[
            TaskItemWidget(
              task: tasks[i],
              onToggleComplete: (val) => _handleToggleComplete(tasks[i].id, val),
              onTogglePause: (val) => _handleTogglePause(tasks[i].id, val),
              onDelete: () => _handleDeleteTask(tasks[i].id),
            ),
            if (i < tasks.length - 1)
              Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 52,
                color: Theme.of(context).dividerColor.withOpacity(0.4),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomCaptureBar(BuildContext context, bool isDark) {
    final barBg = isDark ? const Color(0xFF131B2E) : Colors.white;
    final hintColor = isDark ? AppTheme.textPlaceholderDark : AppTheme.textPlaceholderLight;
    final primaryColor = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing20,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: barBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          QuickCaptureBottomSheet.show(
            context,
            defaultTargetDate: _selectedDate,
            onSubmit: _handleCreateTask,
          );
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '随时随心记录 · 支持智能提取与精准时分秒',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: hintColor,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.tune_rounded, size: 18, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAestheticEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E).withOpacity(0.5) : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? AppTheme.primaryDark : AppTheme.primaryLight).withOpacity(0.1),
                ),
                child: Icon(
                  Icons.spa_rounded,
                  size: 36,
                  color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '该日暂无安排 · 心流从容',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '所有精彩都始于当下。点击底部栏，随手记下第一条计划或精确闹钟。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  String _formatSelectedDisplayDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      final m = dt.month;
      final d = dt.day;
      final w = weekdays[dt.weekday - 1];
      return '$m月$d日 周$w';
    } catch (_) {
      return dateStr;
    }
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 9) return '🌅 清晨心流 · 开启今天';
    if (hour < 12) return '☀️ 上午专注 · 全力推进';
    if (hour < 14) return '☕ 午间轻歇 · 从容节奏';
    if (hour < 18) return '💼 午后心流 · 稳步达成';
    return '🌙 晚间复盘 · 享受从容';
  }
}
