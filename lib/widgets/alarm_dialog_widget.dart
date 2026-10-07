import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/sound_haptic_service.dart';
import '../theme/app_theme.dart';

/// 强力到点闹钟循环提醒弹窗 (AlarmDialogWidget)
/// 特性：音乐持续循环响铃，配合周期脉冲振动，直到用户点击“关闭提醒”
class AlarmDialogWidget extends StatefulWidget {
  final TaskModel task;
  final VoidCallback onDismiss;
  final VoidCallback onSnooze;

  const AlarmDialogWidget({
    super.key,
    required this.task,
    required this.onDismiss,
    required this.onSnooze,
  });

  static Future<void> show(
    BuildContext context, {
    required TaskModel task,
    required VoidCallback onDismiss,
    required VoidCallback onSnooze,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false, // 强制必须手动点击关闭
      builder: (ctx) => AlarmDialogWidget(
        task: task,
        onDismiss: onDismiss,
        onSnooze: onSnooze,
      ),
    );
  }

  @override
  State<AlarmDialogWidget> createState() => _AlarmDialogWidgetState();
}

class _AlarmDialogWidgetState extends State<AlarmDialogWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // 呼吸律动动效
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 启动循环音乐与脉冲振动
    SoundHapticService.instance.startAlarm(
      customAudioPath: widget.task.customSoundPath,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    SoundHapticService.instance.stopAlarm();
    Navigator.of(context).pop();
    widget.onDismiss();
  }

  void _handleSnooze() {
    SoundHapticService.instance.stopAlarm();
    Navigator.of(context).pop();
    widget.onSnooze();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E20) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final amberColor = isDark ? AppTheme.statusPostponedDark : AppTheme.statusPostponedLight;

    return PopScope(
      canPop: false, // 阻止返回键随便退出
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: cardColor,
        elevation: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 律动呼吸闹钟图标
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: amberColor.withOpacity(0.15),
                  ),
                  child: Icon(
                    Icons.alarm_on_rounded,
                    size: 40,
                    color: amberColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                '日程到点强提醒',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: amberColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // 2. 任务标题与计划时间
              Text(
                widget.task.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '时间：${widget.task.targetDate} ${widget.task.timeSlot ?? ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_note_rounded, size: 14, color: amberColor),
                    const SizedBox(width: 4),
                    Text(
                      widget.task.customSoundPath != null ? '自定义本地音乐循环中...' : '专属闹钟铃声循环中...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. 核心大按钮：关闭提醒 (停止响铃)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amberColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '✓ 关闭提醒 (停止响铃)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 稍后 5 分钟提醒
              TextButton(
                onPressed: _handleSnooze,
                child: Text(
                  '稍后 5 分钟再提醒',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
