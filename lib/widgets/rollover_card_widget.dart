import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/sound_haptic_service.dart';

/// 晨间温和结算卡片组件 (Yesterday's Rollover Card)
/// 设计原则：低饱和度、温和文案、绝不弹窗阻断、一键顺延或归档
class RolloverCardWidget extends StatefulWidget {
  final int pendingCount;
  final VoidCallback onBatchPostpone;
  final VoidCallback onBatchArchive;

  const RolloverCardWidget({
    super.key,
    required this.pendingCount,
    required this.onBatchPostpone,
    required this.onBatchArchive,
  });

  @override
  State<RolloverCardWidget> createState() => _RolloverCardWidgetState();
}

class _RolloverCardWidgetState extends State<RolloverCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.4, 0.0, 0.2, 1.0),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.value = 1.0; // 默认展开
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismissAndExecute(VoidCallback callback) {
    if (_isDismissed) return;
    setState(() => _isDismissed = true);
    _controller.reverse().then((_) {
      callback();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pendingCount <= 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppTheme.statusPostponedBgDark
        : AppTheme.statusPostponedBgLight;
    final borderColor = isDark
        ? const Color(0xFF423419)
        : const Color(0xFFFDE68A);
    final amberColor = isDark
        ? AppTheme.statusPostponedDark
        : AppTheme.statusPostponedLight;
    final textColor = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.textPrimaryLight;

    return SizeTransition(
      sizeFactor: _expandAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.only(
            left: AppTheme.spacing20,
            right: AppTheme.spacing20,
            bottom: AppTheme.spacing20,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            child: [
              Row(
                children: [
                  Icon(
                    Icons.wb_twilight_rounded,
                    size: 18,
                    color: amberColor,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      '新的一天：昨日有 ${widget.pendingCount} 项未完待办',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
              Row(
                children: [
                  // 核心操作 1：一键顺延至今日
                  ElevatedButton(
                    onPressed: () {
                      SoundHapticService.instance.playTaskCreated();
                      _dismissAndExecute(widget.onBatchPostpone);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amberColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '全部顺延至今日',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  // 核心操作 2：一键移入沉淀箱
                  TextButton(
                    onPressed: () {
                      SoundHapticService.instance.playTaskDeleted();
                      _dismissAndExecute(widget.onBatchArchive);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondaryLight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '移入沉淀箱',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
