import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../repositories/task_repository.dart';
import '../services/time_parser_service.dart';
import '../services/sound_haptic_service.dart';
import '../theme/app_theme.dart';
import '../widgets/task_item_widget.dart';
import '../widgets/rollover_card_widget.dart';
import '../widgets/quick_capture_bottom_sheet.dart';

/// 今日聚焦主页面 (TodayScreen)
/// 设计原则：首屏即聚焦、无多余 Tab、零认知负荷、沉浸感
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
  late String _todayStr;
  List<TaskModel> _todayTasks = [];
  List<TaskModel> _yesterdayPendingTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshDateAndLoad();
  }

  void _refreshDateAndLoad() {
    _todayStr = TimeParserService.formatDate(DateTime.now());
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    final todayTasks = await widget.repository.getTasksForDate(_todayStr);
    final pendingTasks = await widget.repository.getUnfinishedTasksBeforeDate(_todayStr);

    if (mounted) {
      setState(() {
        _todayTasks = todayTasks;
        _yesterdayPendingTasks = pendingTasks;
        _isLoading = false;
      });
    }
  }

  /// 晨间一键全部顺延至今日
  Future<void> _handleBatchPostpone() async {
    await widget.repository.batchPostponeYesterdayTasks(
      beforeDate: _todayStr,
      todayDate: _todayStr,
    );
    await _loadAllData();
  }

  /// 晨间一键将昨日余项移入沉淀箱
  Future<void> _handleBatchArchive() async {
    await widget.repository.batchArchiveYesterdayTasks(_todayStr);
    await _loadAllData();
  }

  /// 新建任务落库
  Future<void> _handleCreateTask(
    String title,
    String targetDate,
    String? timeSlot,
    String rawInput,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newTask = TaskModel(
      id: const Uuid().v4(),
      title: title,
      rawInput: rawInput,
      targetDate: targetDate,
      timeSlot: timeSlot,
      status: TaskStatus.todo,
      createdAt: now,
      updatedAt: now,
    );

    await widget.repository.createTask(newTask);

    // 如果创建的是今天的任务，立即刷新列表
    if (targetDate == _todayStr) {
      await _loadAllData();
    }
  }

  /// 切换任务完成状态
  Future<void> _handleToggleComplete(String taskId, bool isCompleted) async {
    await widget.repository.toggleTaskCompletion(taskId, isCompleted);
    // 静默刷新数据源
    final updated = await widget.repository.getTasksForDate(_todayStr);
    if (mounted) {
      setState(() => _todayTasks = updated);
    }
  }

  /// 单任务顺延至明天
  Future<void> _handlePostponeToTomorrow(String taskId) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr = TimeParserService.formatDate(tomorrow);
    await widget.repository.postponeTask(taskId, tomorrowStr);
    await _loadAllData();
  }

  /// 单任务移入沉淀箱
  Future<void> _handleArchiveSingle(String taskId) async {
    final task = _todayTasks.firstWhere((t) => t.id == taskId);
    await widget.repository.updateTask(task.copyWith(
      status: TaskStatus.archived,
      archivedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryTextColor = AppTheme.textSecondaryLight;
    final cardColor = isDark ? AppTheme.cardDark : AppTheme.cardLight;

    // 筛选具体时刻项与随时处理项
    final timedTasks = _todayTasks.where((t) => t.hasSpecificTime).toList();
    final anytimeTasks = _todayTasks.where((t) => !t.hasSpecificTime).toList();
    final activeCount = _todayTasks.where((t) => !t.isCompleted).length;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // 1. 顶部大标题栏 (Header Area)
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.spacing20,
                right: AppTheme.spacing20,
                top: AppTheme.spacing16,
                bottom: AppTheme.spacing12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDisplayDate(DateTime.now()),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeCount > 0 ? '今日聚焦 $activeCount 项待办' : '今日已全部完成',
                        style: TextStyle(
                          fontSize: 14,
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

            // 2. 核心任务流展示区
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : RefreshIndicator(
                      onRefresh: () async => _loadAllData(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.only(bottom: 80),
                        children: [
                          // 晨间温和结算卡片
                          if (_yesterdayPendingTasks.isNotEmpty)
                            RolloverCardWidget(
                              pendingCount: _yesterdayPendingTasks.length,
                              onBatchPostpone: _handleBatchPostpone,
                              onBatchArchive: _handleBatchArchive,
                            ),

                          // 空状态视图
                          if (_todayTasks.isEmpty)
                            _buildEmptyState(isDark)
                          else ...[
                            // 分组 1: 具体时钟点
                            if (timedTasks.isNotEmpty) ...[
                              _buildSectionTitle('具体时间', secondaryTextColor),
                              _buildTaskGroup(timedTasks, cardColor),
                              const SizedBox(height: AppTheme.spacing16),
                            ],

                            // 分组 2: 随时处理
                            if (anytimeTasks.isNotEmpty) ...[
                              _buildSectionTitle('随时处理', secondaryTextColor),
                              _buildTaskGroup(anytimeTasks, cardColor),
                            ],
                          ],
                        ],
                      ),
                    ),
            ),

            // 3. 底部极简单行录入唤起栏 (Floating Capture Trigger)
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
                color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                '记录今天的事项或输入具体时间...',
                style: TextStyle(
                  fontSize: 14,
                  color: hintColor,
                  fontWeight: FontWeight.w400,
                ),
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
              Icons.done_all_rounded,
              size: 48,
              color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              '今日待办已清空',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '从容专注于此刻的心流',
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
                            subtitle: Text('原计划: ${t.targetDate} · 顺延 ${t.rolloverCount} 次',
                                style: const TextStyle(fontSize: 12)),
                            trailing: TextButton(
                              onPressed: () async {
                                await widget.repository.updateTask(t.copyWith(
                                  targetDate: _todayStr,
                                  status: TaskStatus.todo,
                                ));
                                Navigator.pop(ctx);
                                _loadAllData();
                              },
                              child: const Text('移至今天'),
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

  String _formatDisplayDate(DateTime dt) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final m = dt.month;
    final d = dt.day;
    final w = weekdays[dt.weekday - 1];
    return '$m月$d日 星期$w';
  }
}
