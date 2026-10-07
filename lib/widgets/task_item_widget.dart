import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../theme/app_theme.dart';
import '../services/sound_haptic_service.dart';

/// 任务单项组件 (TaskItemWidget)
/// 交互设计严格对齐用户需求：
/// 1. 不设左滑/右滑手势删除，已完成/待办项均永久稳固保留在当天
/// 2. 点击任务弹出详情操作方框：包含【完成】、【暂停】、【删除】三大选择
/// 3. 【完成】：勾选亮起翠绿色圆圈与绿勾，任务划线
/// 4. 【暂停】：整条任务变为半透明置灰（Opacity: 0.35），带暂停徽标
/// 5. 【删除】：永久移除该行记录
class TaskItemWidget extends StatefulWidget {
  final TaskModel task;
  final ValueChanged<bool> onToggleComplete;
  final ValueChanged<bool> onTogglePause;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const TaskItemWidget({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onTogglePause,
    required this.onDelete,
    this.onTap,
  });

  @override
  State<TaskItemWidget> createState() => _TaskItemWidgetState();
}

class _TaskItemWidgetState extends State<TaskItemWidget> {
  void _handleCheckboxTap() {
    if (widget.task.isCompleted) {
      SoundHapticService.instance.playTaskCreated();
      widget.onToggleComplete(false);
    } else {
      SoundHapticService.instance.playTaskCompleted();
      widget.onToggleComplete(true);
    }
  }

  /// 弹出详细内容与【完成/暂停/删除】操作方框
  void _showDetailActionDialog(BuildContext context) {
    SoundHapticService.instance.playSelectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppTheme.cardDark : Colors.white;
    final primaryTextColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryTextColor = AppTheme.textSecondaryLight;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.primaryDark : AppTheme.primaryLight).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.task.hasSpecificTime ? Icons.schedule_rounded : Icons.task_alt_rounded,
                  size: 20,
                  color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '日程详细安排',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 任务标题
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  widget.task.title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 详细元数据信息
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 15, color: secondaryTextColor),
                  const SizedBox(width: 6),
                  Text('计划日期: ${widget.task.targetDate}', style: TextStyle(fontSize: 13, color: secondaryTextColor)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.access_time_filled_rounded, size: 15, color: secondaryTextColor),
                  const SizedBox(width: 6),
                  Text(
                    '时间时刻: ${widget.task.timeSlot ?? '全天 / 随时推进'}',
                    style: TextStyle(fontSize: 13, color: secondaryTextColor),
                  ),
                ],
              ),
              if (widget.task.hasAlarm) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.notifications_active_rounded, size: 15, color: AppTheme.badgeAlarmLight),
                    const SizedBox(width: 6),
                    Text(
                      '强力到点闹钟: 已开启循环提醒',
                      style: TextStyle(fontSize: 13, color: isDark ? AppTheme.badgeAlarmDark : AppTheme.badgeAlarmLight),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
            ],
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 完成选项按键
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _handleCheckboxTap();
                  },
                  icon: Icon(
                    widget.task.isCompleted ? Icons.undo_rounded : Icons.check_circle_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    widget.task.isCompleted ? '取消完成状态' : '标记为已完成 (亮起绿勾)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.task.isCompleted
                        ? (isDark ? const Color(0xFF475569) : const Color(0xFF64748B))
                        : (isDark ? AppTheme.statusSuccessDark : AppTheme.statusSuccessLight),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 8),

                // 2. 暂停选项按键 (整条变半透明)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    SoundHapticService.instance.playSelectionClick();
                    widget.onTogglePause(!widget.task.isPaused);
                  },
                  icon: Icon(
                    widget.task.isPaused ? Icons.play_arrow_rounded : Icons.pause_circle_outline_rounded,
                    size: 18,
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                  ),
                  label: Text(
                    widget.task.isPaused ? '恢复正常推进' : '暂停推进 (整条变半透明)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),

                // 3. 删除选项按键 (删掉这一行)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    SoundHapticService.instance.playTaskDeleted();
                    widget.onDelete();
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  label: const Text(
                    '删除这一行记录',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.redAccent),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryTextColor = AppTheme.textSecondaryLight;
    final cardColor = isDark ? AppTheme.cardDark : AppTheme.cardLight;

    // 暂停状态整条半透明 (0.35)，已完成轻度置灰
    final double itemOpacity = widget.task.isPaused
        ? 0.35
        : (widget.task.isCompleted ? 0.65 : 1.0);

    return Opacity(
      opacity: itemOpacity,
      child: InkWell(
        onTap: () {
          if (widget.onTap != null) {
            widget.onTap!();
          } else {
            _showDetailActionDialog(context);
          }
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 56.0),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: 12,
          ),
          color: cardColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. 精致 Checkbox (点击即亮起绿勾或反选)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleCheckboxTap,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.task.isCompleted
                          ? (isDark ? AppTheme.statusSuccessDark : AppTheme.statusSuccessLight)
                          : Colors.transparent,
                      border: Border.all(
                        color: widget.task.isCompleted
                            ? Colors.transparent
                            : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                        width: 1.8,
                      ),
                    ),
                    child: widget.task.isCompleted
                        ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. 任务标题文本与暂停标记
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (widget.task.isPaused) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '已暂停',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            widget.task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              color: widget.task.isCompleted
                                  ? secondaryTextColor.withOpacity(0.5)
                                  : primaryTextColor,
                              decoration: widget.task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: secondaryTextColor.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. 精致时钟胶囊徽标
              if (widget.task.hasSpecificTime) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.badgeTimeBgDark : AppTheme.badgeTimeBgLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: isDark ? AppTheme.badgeTimeDark : AppTheme.badgeTimeLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.task.timeSlot!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.badgeTimeDark : AppTheme.badgeTimeLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 4. 强力闹钟金标 (金色圆标)
              if (widget.task.hasAlarm && !widget.task.isCompleted) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.badgeAlarmBgDark : AppTheme.badgeAlarmBgLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    size: 13,
                    color: isDark ? AppTheme.badgeAlarmDark : AppTheme.badgeAlarmLight,
                  ),
                ),
              ],

              // 5. 本地自定义音乐标
              if (widget.task.customSoundPath != null && !widget.task.isCompleted) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.badgeSuccessBgDark : AppTheme.badgeSuccessBgLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 12,
                    color: isDark ? AppTheme.badgeSuccessDark : AppTheme.badgeSuccessLight,
                  ),
                ),
              ],

              // 6. 点击展开菜单提示微图标
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: secondaryTextColor.withOpacity(0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
