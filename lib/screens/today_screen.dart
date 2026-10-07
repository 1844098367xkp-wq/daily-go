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

/// 全局日程表主页面 (ScheduleScreen / TodayScreen)
/// 特性：
/// 1. 顶部横向日期轴：支持自由定位到任意一天（昨天/今天/明天/未来）查看具体时间安排
/// 2. 精确时间流：所有安排严格按具体时间点 (HH:mm:ss) 排序展示
/// 3. 本地强力闹钟调度器：精确秒级触发循环音乐，弹窗要求手动关闭
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

  // 闹钟检测定时器 (秒级检测)
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

  /// 启动本地秒级闹钟守护检测器
  void _startAlarmDaemon() {
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkAndTriggerAlarms();
    });
  }

  /// 检查是否有任务到达设定的具体时刻
  Future<void> _checkAndTriggerAlarms() async {
    final now = DateTime.now();
    final todayStr = TimeParserService.formatDate(now);
    final nowTimeStr = TimeParserService.formatTime(now.hour, now.minute, now.second);
    final nowShortTimeStr = TimeParserService.formatTime(now.hour, now.minute);

    // 仅在真实今天检查闹钟
    for (final task in _currentDateTasks) {
      if (task.targetDate == todayStr &&
          !task.isCompleted &&
          task.hasAlarm &&
          task.timeSlot != null &&
          !_triggeredAlarmTaskIds.contains(task.id)) {
        // 支持精确到秒 (HH:mm:ss) 或 精确到分 (HH:mm)
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

  /// 弹出全屏呼吸闹钟卡片
  void _popAlarmDialog(TaskModel task) {
    if (!mounted) return;
    AlarmDialogWidget.show(
      context,
      task: task,
      onDismiss: () {
        // 用户主动点击“关闭提醒”
      },
      onSnooze: () {
        // 稍后 5 分钟提醒：5分钟后移除触发缓存
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

    // 扫描有任务的日期标记
    final allUpcoming = await widget.repository.getTasksForDate(_selectedDate);
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

  /// 晨间一键顺延昨日未完成项至今天
  Future<void> _handleBatchPostpone() async {
    await widget.repository.batchPostponeYesterdayTasks(
      beforeDate: _realTodayStr,
      todayDate: _realTodayStr,
    );
    await _loadData();
  }

  /// 晨间一键将昨日余项移入沉淀箱
  Future<void> _handleBatchArchive() async {
    await widget.repository.batchArchiveYesterdayTasks(_realTodayStr);
    await _loadData();
  }

  /// 新建任务落库 (支持精确年月日时分秒、强闹钟与自定义音乐)
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

    // 如果创建的日期正是当前浏览的日期，刷新视图
    if (targetDate == _selectedDate) {
      await _loadData();
    } else {
      // 切换到所创建日期的日程表
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

  /// 单任务顺延至明天
  Future<void> _handlePostponeToTomorrow(String taskId) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr = TimeParserService.formatDate(tomorrow);
    await widget.repository.postponeTask(taskId, tomorrowStr);
    await _loadData();
  }

  /// 单任务移入沉淀箱
  Future<void> _handleArchiveSingle(String taskId) async {
    final task = _currentDateTasks.firstWhere((t) => t.id == taskId);
    await widget.repository.updateTask(task.copyWith(
      status: TaskStatus.archived,
      archivedAt: DateTime.now().millisecondsSinceEpoch,
    ));
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
    final activeCount = _currentDateTasks.where((t) => !t.isCompleted).length;
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

            // 2. 所选日期标题栏
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.spacing20,
                right: AppTheme.spacing20,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _formatSelectedDisplayDate(_selectedDate),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: primaryTextColor,
                            ),
                          ),
                          if (!isViewingToday) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _handleDateChanged(_realTodayStr),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '回到今天',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        activeCount > 0 ? '该日已规划 $activeCount 项待办' : '该日事项已全部搞定',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  // 沉淀箱入口小按钮
                  IconButton(
                    onPressed: () => _openArchivedSheet(context),
                    icon: Icon(
                      Icons.inventory_2_outlined,
                      size: 22,
                      color: secondaryTextColor,
                    ),
                    tooltip: '沉淀箱',
                  ),
                ],
              ),
            ),

            // 3. 核心任务流展示区 (按具体时间精确排序)
            Expanded(
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
                          // 仅在查看“今天”时展示晨间结算卡片
                          if (isViewingToday && _yesterdayPendingTasks.isNotEmpty)
                            RolloverCardWidget(
                              pendingCount: _yesterdayPendingTasks.length,
                              onBatchPostpone: _handleBatchPostpone,
                              onBatchArchive: _handleBatchArchive,
                            ),

                          // 空状态视图
                          if (_currentDateTasks.isEmpty)
                            _buildEmptyState(isDark)
                          else ...[
                            // 分组 1: 具体时钟点 (按精确时间由早到晚展示)
                            if (timedTasks.isNotEmpty) ...[
                              _buildSectionTitle('具体时间安排', secondaryTextColor),
                              _buildTaskGroup(timedTasks, cardColor),
                              const SizedBox(height: AppTheme.spacing16),
                            ],

                            // 分组 2: 随时处理 (无具体时钟点)
                            if (anytimeTasks.isNotEmpty) ...[
                              _buildSectionTitle('全天 / 随时处理', secondaryTextColor),
                              _buildTaskGroup(anytimeTasks, cardColor),
                            ],
                          ],
                        ],
                      ),
                    ),
            ),

            // 4. 底部录入唤起栏 (点击打开支持智能提取与年月日时分秒的弹窗)
            _buildBottomCaptureBar(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacing20,
        bottom: AppTheme.spacing8,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTaskGroup(List<TaskModel> tasks, Color cardColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < tasks.length; i++) ...[
            TaskItemWidget(
              task: tasks[i],
              onToggleComplete: (val) => _handleToggleComplete(tasks[i].id, val),
              onPostpone: () => _handlePostponeToTomorrow(tasks[i].id),
              onArchive: () => _handleArchiveSingle(tasks[i].id),
            ),
            if (i < tasks.length - 1)
              Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 46,
                color: Theme.of(context).dividerColor,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomCaptureBar(BuildContext context, bool isDark) {
    final barBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final hintColor = isDark ? AppTheme.textPlaceholderDark : AppTheme.textPlaceholderLight;
    final primaryColor = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing20,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
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
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(
                Icons.add_rounded,
                size: 20,
                color: primaryColor,
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text(
                  '添加安排，支持智能识别或精确到时分秒...',
                  style: TextStyle(
                    fontSize: 14,
                    color: hintColor,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 48,
              color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              '该日期暂无日程安排',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '点击下方栏目快速添加，可设置精确到秒的强闹钟',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.textPlaceholderDark : AppTheme.textPlaceholderLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openArchivedSheet(BuildContext context) async {
    final archived = await widget.repository.getArchivedTasks();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.sheetDark : AppTheme.sheetLight,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusLarge),
              topRight: Radius.circular(AppTheme.radiusLarge),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.textPlaceholderDark : AppTheme.textPlaceholderLight,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '沉淀箱 (稍后处理与归档)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: archived.isEmpty
                    ? const Center(child: Text('暂无沉淀任务', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: archived.length,
                        itemBuilder: (c, idx) {
                          final t = archived[idx];
                          return ListTile(
                            title: Text(t.title, style: const TextStyle(fontSize: 15)),
                            subtitle: Text('原计划: ${t.targetDate} ${t.timeSlot ?? ''} · 顺延 ${t.rolloverCount} 次',
                                style: const TextStyle(fontSize: 12)),
                            trailing: TextButton(
                              onPressed: () async {
                                await widget.repository.updateTask(t.copyWith(
                                  targetDate: _selectedDate,
                                  status: TaskStatus.todo,
                                ));
                                Navigator.pop(ctx);
                                _loadData();
                              },
                              child: const Text('移至该日'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
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
      return '$m月$d日 星期$w';
    } catch (_) {
      return dateStr;
    }
  }
}
