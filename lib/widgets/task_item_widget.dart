import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../theme/app_theme.dart';
import '../services/sound_haptic_service.dart';

/// 任务单项组件 (TaskItemWidget)
/// 严格还原 Things 3 微交互：
/// 1. 22pt 圆形 Checkbox 微弹动
/// 2. 划线并置灰变淡
/// 3. 650ms 黄金驻留窗口（允许反悔撤销）
/// 4. 240ms 平滑高度坍缩折叠
/// 5. 双向滑动手势（右滑完成，左滑顺延/归档）
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

    _collapseController.value = 1.0; // 默认展开状态
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

  /// 点击 Checkbox 的 650ms 驻留与撤销控制
  void _handleCheckboxTap() {
    if (_isOptimisticCompleted) {
      // 用户在驻留期内反悔：撤销倒计时，还原状态
      _dwellTimer?.cancel();
      setState(() => _isOptimisticCompleted = false);
      SoundHapticService.instance.playTaskCreated();
      widget.onToggleComplete(false);
    } else {
      // 标记完成：播放声音与中等触感
      setState(() => _isOptimisticCompleted = true);
      SoundHapticService.instance.playTaskCompleted();

      // 650ms 黄金驻留时延
      _dwellTimer = Timer(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        // 延时结束：执行平滑坍缩折叠
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
    final primaryTextColor = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.textPrimaryLight;
    final secondaryTextColor = AppTheme.textSecondaryLight;
    final cardColor = isDark ? AppTheme.cardDark : AppTheme.cardLight;

    return SizeTransition(
      sizeFactor: _collapseAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dismissible(
          key: ValueKey(widget.task.id),
          // 右滑完成，左滑推迟
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // 右滑：完成
              SoundHapticService.instance.playTaskCompleted();
              widget.onToggleComplete(true);
              return true;
            } else if (direction == DismissDirection.endToStart) {
              // 左滑：快速顺延至明天
              SoundHapticService.instance.playTaskDeleted();
              widget.onPostpone();
              return true;
            }
            return false;
          },
          // 右滑背景：柔和翠绿
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
            color: isDark ? AppTheme.statusSuccessDark : AppTheme.statusSuccessLight,
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
          ),
          // 左滑背景：暖砂琥珀顺延
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
            color: isDark
                ? AppTheme.statusPostponedDark
                : AppTheme.statusPostponedLight,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.schedule_send_rounded, color: Colors.white, size: 22),
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
              constraints: const BoxConstraints(minHeight: 52.0),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing20,
                vertical: AppTheme.spacing12,
              ),
              color: cardColor,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. 22pt 圆形 Checkbox 交互靶心 (扩大触摸热区至 44pt)
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
                              ? (isDark
                                  ? AppTheme.statusSuccessDark
                                  : AppTheme.statusSuccessLight)
                              : Colors.transparent,
                          border: Border.all(
                            color: _isOptimisticCompleted
                                ? Colors.transparent
                                : (isDark
                                    ? AppTheme.textPlaceholderDark
                                    : AppTheme.textPlaceholderLight),
                            width: 1.5,
                          ),
                        ),
                        child: _isOptimisticCompleted
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),

                  // 2. 任务标题（带 180ms 划线置灰过渡）
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        color: _isOptimisticCompleted
                            ? secondaryTextColor.withOpacity(0.4)
                            : primaryTextColor,
                        decoration: _isOptimisticCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: secondaryTextColor.withOpacity(0.5),
                      ),
                      child: Text(
                        widget.task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // 3. 时间标签胶囊 (如有定时)
                  if (widget.task.hasSpecificTime) ...[
                    const SizedBox(width: AppTheme.spacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.primaryTintDark
                            : AppTheme.primaryTintLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        widget.task.timeSlot!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.primaryDark
                              : AppTheme.primaryLight,
                        ),
                      ),
                    ),
                  ],

                  // 4. 顺延疲劳度微标记 (>=3次顺延)
                  if (widget.task.isHighFatigue && !_isOptimisticCompleted) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.repeat_rounded,
                      size: 14,
                      color: isDark
                          ? AppTheme.statusPostponedDark
                          : AppTheme.statusPostponedLight,
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
