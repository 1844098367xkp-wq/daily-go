import 'package:flutter/material.dart';
import '../services/time_parser_service.dart';
import '../services/sound_haptic_service.dart';
import '../theme/app_theme.dart';
import 'precise_time_picker_dialog.dart';

/// 底部快速新建弹窗 (升级版)
/// 双轨合一：
/// 1. 智能自然语言识别 (打字实时抽取年月日时分秒)
/// 2. 显式精确时间设置入口 (可精确到年月日时分秒 + 循环强闹钟 + 本地音乐)
class QuickCaptureBottomSheet extends StatefulWidget {
  final String defaultTargetDate;
  final Function(
    String title,
    String targetDate,
    String? timeSlot,
    String rawInput,
    bool hasAlarm,
    String? customSoundPath,
  ) onSubmit;

  const QuickCaptureBottomSheet({
    super.key,
    required this.defaultTargetDate,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required String defaultTargetDate,
    required Function(
      String title,
      String targetDate,
      String? timeSlot,
      String rawInput,
      bool hasAlarm,
      String? customSoundPath,
    ) onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickCaptureBottomSheet(
        defaultTargetDate: defaultTargetDate,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<QuickCaptureBottomSheet> createState() => _QuickCaptureBottomSheetState();
}

class _QuickCaptureBottomSheetState extends State<QuickCaptureBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  ParsedTaskInput? _currentParsed;
  bool _ignoreAutoTime = false;

  // 显式手动精确配置
  late String _manualTargetDate;
  String? _manualTimeSlot;
  bool _hasAlarm = true;
  String? _customSoundPath;

  @override
  void initState() {
    super.initState();
    _manualTargetDate = widget.defaultTargetDate;
    _textController.addListener(_handleTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final text = _textController.text;
    if (_ignoreAutoTime || text.trim().isEmpty) {
      setState(() => _currentParsed = null);
      return;
    }

    final parsed = TimeParserService.parse(text);
    if (parsed.hasExplicitTime) {
      setState(() {
        _currentParsed = parsed;
        _manualTargetDate = parsed.targetDate;
        _manualTimeSlot = parsed.timeSlot;
      });
    } else {
      setState(() => _currentParsed = null);
    }
  }

  /// 呼出精确到年月日时分秒与本地音乐的弹窗
  Future<void> _openPreciseTimePicker() async {
    DateTime baseDt;
    try {
      final parts = _manualTargetDate.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      int h = 9, min = 0, s = 0;
      if (_manualTimeSlot != null) {
        final timeParts = _manualTimeSlot!.split(':');
        h = int.parse(timeParts[0]);
        min = int.parse(timeParts[1]);
        if (timeParts.length > 2) s = int.parse(timeParts[2]);
      }
      baseDt = DateTime(y, m, d, h, min, s);
    } catch (_) {
      baseDt = DateTime.now();
    }

    final result = await PreciseTimePickerDialog.show(
      context,
      initialDateTime: baseDt,
      initialHasAlarm: _hasAlarm,
      initialSoundPath: _customSoundPath,
    );

    if (result != null) {
      setState(() {
        _manualTargetDate = result['targetDate'] as String;
        _manualTimeSlot = result['timeSlot'] as String?;
        _hasAlarm = (result['hasAlarm'] as bool?) ?? true;
        _customSoundPath = result['customSoundPath'] as String?;
        _ignoreAutoTime = true; // 用户显式微调后，优先使用手动设置
      });
    }
  }

  void _submit() {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty) return;

    final parsed = _currentParsed ?? TimeParserService.parse(rawText);
    final finalTitle = parsed.title.isEmpty ? rawText : parsed.title;

    SoundHapticService.instance.playTaskCreated();

    widget.onSubmit(
      finalTitle,
      _manualTargetDate,
      _manualTimeSlot,
      rawText,
      _hasAlarm,
      _customSoundPath,
    );

    Navigator.of(context).pop();
  }

  void _applyQuickShortcut(int daysOffset) {
    final target = DateTime.now().add(Duration(days: daysOffset));
    final dateStr = TimeParserService.formatDate(target);
    final rawText = _textController.text.trim();

    widget.onSubmit(
      rawText.isEmpty ? '待办事项' : rawText,
      dateStr,
      null,
      rawText,
      _hasAlarm,
      _customSoundPath,
    );
    SoundHapticService.instance.playTaskCreated();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? AppTheme.sheetDark : AppTheme.sheetLight;
    final primaryTextColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final primaryColor = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusLarge),
          topRight: Radius.circular(AppTheme.radiusLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 顶部拖拽条
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.textPlaceholderDark : AppTheme.textPlaceholderLight,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // 2. 文本输入区 (支持打字智能提取)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing20,
                vertical: AppTheme.spacing8,
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: TextStyle(
                  fontSize: 17,
                  color: primaryTextColor,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: '记录事项，支持如“明天14:30 方案评审”...',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: isDark ? AppTheme.textPlaceholderDark : AppTheme.textPlaceholderLight,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            // 3. 实时时间识别胶囊与精确时间微调按钮
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.spacing20,
                right: AppTheme.spacing20,
                bottom: AppTheme.spacing8,
              ),
              child: Row(
                children: [
                  // 时间标签胶囊 (不管是自动提取还是手动设置)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.primaryTintDark : AppTheme.primaryTintLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _hasAlarm ? Icons.alarm_on_rounded : Icons.calendar_today_rounded,
                          size: 13,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_manualTargetDate ${_manualTimeSlot ?? '(全天)'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                        if (_manualTimeSlot != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _manualTimeSlot = null;
                                _ignoreAutoTime = true;
                                _currentParsed = null;
                              });
                            },
                            child: Icon(Icons.close_rounded, size: 14, color: primaryColor),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 精确时间 (年月日时分秒) 入口
                  GestureDetector(
                    onTap: _openPreciseTimePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 13, color: AppTheme.textSecondaryLight),
                          const SizedBox(width: 3),
                          Text(
                            '精确时分秒/音乐',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              thickness: 0.5,
              color: isDark ? AppTheme.separatorDark : AppTheme.separatorLight,
            ),

            // 4. 键盘辅助条 (快捷注入 + 提交)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: 6,
              ),
              child: Row(
                children: [
                  _buildQuickPill('今天', () => _applyQuickShortcut(0), isDark),
                  const SizedBox(width: 6),
                  _buildQuickPill('明天', () => _applyQuickShortcut(1), isDark),
                  const SizedBox(width: 6),
                  _buildQuickPill('后天', () => _applyQuickShortcut(2), isDark),
                  const Spacer(),
                  IconButton(
                    onPressed: _submit,
                    icon: Icon(Icons.arrow_upward_rounded, color: primaryColor),
                    iconSize: 22,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPill(String label, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242426) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}
