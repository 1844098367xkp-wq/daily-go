import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../services/time_parser_service.dart';

/// 精确到年月日时分秒的高级时间与音乐配置弹窗
class PreciseTimePickerDialog extends StatefulWidget {
  final DateTime initialDateTime;
  final bool initialHasAlarm;
  final String? initialSoundPath;

  const PreciseTimePickerDialog({
    super.key,
    required this.initialDateTime,
    this.initialHasAlarm = true,
    this.initialSoundPath,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required DateTime initialDateTime,
    bool initialHasAlarm = true,
    String? initialSoundPath,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PreciseTimePickerDialog(
        initialDateTime: initialDateTime,
        initialHasAlarm: initialHasAlarm,
        initialSoundPath: initialSoundPath,
      ),
    );
  }

  @override
  State<PreciseTimePickerDialog> createState() => _PreciseTimePickerDialogState();
}

class _PreciseTimePickerDialogState extends State<PreciseTimePickerDialog> {
  late int _year;
  late int _month;
  late int _day;
  late int _hour;
  late int _minute;
  late int _second;
  late bool _hasAlarm;
  String? _customSoundPath;
  String? _customSoundName;

  @override
  void initState() {
    super.initState();
    final dt = widget.initialDateTime;
    _year = dt.year;
    _month = dt.month;
    _day = dt.day;
    _hour = dt.hour;
    _minute = dt.minute;
    _second = dt.second;
    _hasAlarm = widget.initialHasAlarm;
    _customSoundPath = widget.initialSoundPath;
    if (_customSoundPath != null) {
      _customSoundName = _customSoundPath!.split(RegExp(r'[/\\]')).last;
    }
  }

  /// 从手机本地选择音乐文件
  Future<void> _pickLocalAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _customSoundPath = result.files.single.path!;
          _customSoundName = result.files.single.name;
        });
      }
    } catch (_) {}
  }

  void _submit() {
    final finalDateStr = TimeParserService.formatDate(DateTime(_year, _month, _day));
    final finalTimeStr = TimeParserService.formatTime(_hour, _minute, _second);

    Navigator.of(context).pop({
      'targetDate': finalDateStr,
      'timeSlot': finalTimeStr,
      'hasAlarm': _hasAlarm,
      'customSoundPath': _customSoundPath,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? AppTheme.sheetDark : AppTheme.sheetLight;
    final textColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final subColor = AppTheme.textSecondaryLight;
    final primaryColor = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20, vertical: 16),
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusLarge),
          topRight: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 拖拽条
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.textPlaceholderDark : AppTheme.textPlaceholderLight,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '精确时间与闹钟设置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),

              // 1. 年月日设置 (可点击系统日历弹窗快捷选择)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.calendar_today_rounded, color: primaryColor),
                title: Text('计划日期 (年月日)', style: TextStyle(color: textColor, fontSize: 15)),
                subtitle: Text('$_year年$_month月$_day日', style: TextStyle(color: subColor, fontSize: 13)),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(_year, _month, _day),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() {
                        _year = picked.year;
                        _month = picked.month;
                        _day = picked.day;
                      });
                    }
                  },
                  child: const Text('更改日期'),
                ),
              ),

              const Divider(height: 1),

              // 2. 精确时分秒设置 (滚轮/数字调整)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_filled_rounded, size: 20, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          '精确时间: ${TimeParserService.formatTime(_hour, _minute, _second)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNumberDropdown('时 (Hour)', 0, 23, _hour, (v) => setState(() => _hour = v), isDark),
                        _buildNumberDropdown('分 (Min)', 0, 59, _minute, (v) => setState(() => _minute = v), isDark),
                        _buildNumberDropdown('秒 (Sec)', 0, 59, _second, (v) => setState(() => _second = v), isDark),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 3. 强力闹钟开关 (循环播放直到手动关闭)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('开启强力到点闹钟', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('到点时持续循环播放音乐，直到点击关闭', style: TextStyle(color: subColor, fontSize: 12)),
                value: _hasAlarm,
                activeColor: primaryColor,
                onChanged: (val) => setState(() => _hasAlarm = val),
              ),

              const Divider(height: 1),

              // 4. 自定义本地音乐挑选
              if (_hasAlarm) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.music_note_rounded, color: primaryColor),
                  title: Text('闹钟提示音乐', style: TextStyle(color: textColor, fontSize: 15)),
                  subtitle: Text(
                    _customSoundName ?? '默认马林巴轻钟铃音',
                    style: TextStyle(color: subColor, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_customSoundPath != null)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() {
                            _customSoundPath = null;
                            _customSoundName = null;
                          }),
                          tooltip: '恢复默认',
                        ),
                      ElevatedButton(
                        onPressed: _pickLocalAudioFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                          foregroundColor: primaryColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        child: const Text('从手机选择', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 确认按钮
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('确认时间与提醒配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberDropdown(String label, int min, int max, int value, ValueChanged<int> onChanged, bool isDark) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242426) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: value,
            underline: const SizedBox(),
            items: List.generate(
              max - min + 1,
              (i) => DropdownMenuItem(
                value: min + i,
                child: Text((min + i).toString().padLeft(2, '0')),
              ),
            ),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
