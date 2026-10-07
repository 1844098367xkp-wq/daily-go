import 'package:flutter/material.dart';
import '../services/time_parser_service.dart';
import '../services/sound_haptic_service.dart';
import '../theme/app_theme.dart';

/// 底部新建弹窗 (QuickCaptureBottomSheet)
/// 特性：
/// 1. 紧密贴合系统软键盘，拇指盲操体验
/// 2. 键入时端侧实时提取时间（如“明天下午3点”）并以高亮胶囊展现
/// 3. 快捷时间注入条：[今天] [明天] [后天]
/// 4. 回车或确认键触发轻脆落库音效与微触感
class QuickCaptureBottomSheet extends StatefulWidget {
  final Function(String title, String targetDate, String? timeSlot, String rawInput) onSubmit;

  const QuickCaptureBottomSheet({
    super.key,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(String title, String targetDate, String? timeSlot, String rawInput) onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickCaptureBottomSheet(onSubmit: onSubmit),
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

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);
    // 打开时自动唤起键盘
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
      setState(() => _currentParsed = parsed);
    } else {
      setState(() => _currentParsed = null);
    }
  }

  void _submit() {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty) return;

    final parsed = _currentParsed ?? TimeParserService.parse(rawText);
    final finalTitle = parsed.title.isEmpty ? rawText : parsed.title;

    // 触发落库微触感与机械咔哒音
    SoundHapticService.instance.playTaskCreated();

    widget.onSubmit(
      finalTitle,
      parsed.targetDate,
      parsed.timeSlot,
      rawText,
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
    );
    SoundHapticService.instance.playTaskCreated();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? AppTheme.sheetDark : AppTheme.sheetLight;
    final primaryTextColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
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
            // 1. 顶部拖拽条 (Grabber: 36pt x 5pt)
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

            // 2. 文本输入区 (单行可延展)
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
                  hintText: '记录事项，支持如“明天下午3点 开会”...',
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

            // 3. 动态时间识别高亮胶囊
            if (_currentParsed != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppTheme.spacing20,
                  right: AppTheme.spacing20,
                  bottom: AppTheme.spacing8,
                ),
                child: Row(
                  children: [
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
                            Icons.local_offer_rounded,
                            size: 13,
                            color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_currentParsed!.targetDate} ${_currentParsed!.timeSlot ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // 点击取消时间解析
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _ignoreAutoTime = true;
                                _currentParsed = null;
                              });
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // 4. 分割线
            Divider(
              height: 1,
              thickness: 0.5,
              color: isDark ? AppTheme.separatorDark : AppTheme.separatorLight,
            ),

            // 5. 键盘辅助条 (Accessory Bar: 快捷日期 + 确认提交)
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
                    icon: Icon(
                      Icons.arrow_upward_rounded,
                      color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                    ),
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
