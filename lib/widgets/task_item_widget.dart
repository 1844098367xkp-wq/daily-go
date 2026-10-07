import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../theme/app_theme.dart';
import '../services/sound_haptic_service.dart';

/// 任务单项组件 (TaskItemWidget)
/// 顶级精美度重构：
/// 1. 22pt 圆形 Checkbox 微弹动与触感
/// 2. 划线并置灰
/// 3. 650ms 黄金驻留撤销窗口 + 240ms 高度平滑坍缩
/// 4. 精美语义彩色微徽标 (时钟徽标、强闹钟金标、本地音乐绿标)
class TaskItemWidget extends StatefulWidget {
  final TaskModel task;
  final ValueChanged<bool> onToggleComplete;
  final VoidCallback onPostpone;
  final VoidCallback onArchive;
  final VoidCallback? onTap;

  const TaskItemWidget({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onPostpone,
    required this.onArchive,
    this.onTap,
  });

  @override
  State<TaskItemWidget> createState() => _TaskItemWidgetState();
}

class _TaskItemWidgetState extends State<TaskItemWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _collapseController;
  late final Animation<double> _collapseAnimation;
  late final Animation<double> _fadeAnimation;

  Timer? _dwellTimer;
  bool _isOptimisticCompleted = false;

  @override
  void initState() {
    super.initState();
    _isOptimisticCompleted = widget.task.isCompleted;

    _collapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _collapseAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: const Cubic(0.4, 0.0, 0.2, 1.0),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeOut,
    );

    _collapseController.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant TaskItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.isCompleted != oldWidget.task.isCompleted) {
      setState(() {
        _isOptimisticCompleted = widget.task.isCompleted;
      });
    }
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _collapseController.dispose();
    super.dispose();
  }

  void _handleCheckboxTap() {
    if (_isOptimisticCompleted) {
      _dwellTimer?.cancel();
      setState(() => _isOptimisticCompleted = false);
      SoundHapticService.instance.playTaskCreated();
      widget.onToggleComplete(false);
    } else {
      setState(() => _isOptimisticCompleted = true);
      SoundHapticService.instance.playTaskCompleted();

      _dwellTimer = Timer(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        _collapseController.reverse().then((_) {
          if (mounted) {
            widget.onToggleComplete(true);
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryTextColor = AppTheme.textSecondaryLight;
    final cardColor = isDark ? AppTheme.cardDark : AppTheme.cardLight;

    return SizeTransition(
      sizeFactor: _collapseAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dismissible(
          key: ValueKey(widget.task.id),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              SoundHapticService.instance.playTaskCompleted();
              widget.onToggleComplete(true);
              return true;
            } else if (direction == DismissDirection.endToStart) {
              SoundHapticService.instance.playTaskDeleted();
              widget.onPostpone();
              return true;
            }
            return false;
          },
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
            color: isDark ? AppTheme.statusSuccessDark : AppTheme.statusSuccessLight,
            child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
            color: isDark ? AppTheme.statusPostponedDark : AppTheme.statusPostponedLight,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.next_plan_rounded, color: Colors.white, size: 22),
                SizedBox(width: 6),
                Text(
                  '顺延至明天',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
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
                  // 1. 精致 Checkbox (触控热区)
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
                          color: _isOptimisticCompleted
                              ? (isDark ? AppTheme.statusSuccessDark : AppTheme.statusSuccessLight)
                              : Colors.transparent,
                          border: Border.all(
                            color: _isOptimisticCompleted
                                ? Colors.transparent
                                : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            width: 1.8,
                          ),
                        ),
                        child: _isOptimisticCompleted
                            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. 任务标题文本
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: _isOptimisticCompleted
                            ? secondaryTextColor.withOpacity(0.35)
                            : primaryTextColor,
                        decoration: _isOptimisticCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: secondaryTextColor.withOpacity(0.4),
                      ),
                      child: Text(
                        widget.task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // 3. 精致时钟与闹钟胶囊徽标
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

                  // 4. 强力闹钟金标 (金色呼吸徽标)
                  if (widget.task.hasAlarm && !_isOptimisticCompleted) ...[
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
                  if (widget.task.customSoundPath != null && !_isOptimisticCompleted) ...[
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
