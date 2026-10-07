import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/sound_haptic_service.dart';
import '../services/time_parser_service.dart';

enum CalendarNavMode {
  days,
  months,
  years,
}

/// 宏观多维日历穿梭矩阵 (年视图 -> 月视图 -> 日视图自由选日)
class MacroCalendarDialog extends StatefulWidget {
  final String initialDate; // YYYY-MM-DD
  final Set<String> datesWithTasks;
  final ValueChanged<String> onDateSelected;

  const MacroCalendarDialog({
    super.key,
    required this.initialDate,
    required this.datesWithTasks,
    required this.onDateSelected,
  });

  static Future<String?> show(
    BuildContext context, {
    required String initialDate,
    required Set<String> datesWithTasks,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => MacroCalendarDialog(
        initialDate: initialDate,
        datesWithTasks: datesWithTasks,
        onDateSelected: (selected) => Navigator.of(ctx).pop(selected),
      ),
    );
  }

  @override
  State<MacroCalendarDialog> createState() => _MacroCalendarDialogState();
}

class _MacroCalendarDialogState extends State<MacroCalendarDialog> {
  late int _viewYear;
  late int _viewMonth;
  late String _selectedDate;
  CalendarNavMode _navMode = CalendarNavMode.days;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    try {
      final parts = widget.initialDate.split('-');
      _viewYear = int.parse(parts[0]);
      _viewMonth = int.parse(parts[1]);
    } catch (_) {
      final now = DateTime.now();
      _viewYear = now.year;
      _viewMonth = now.month;
    }
  }

  void _prevMonth() {
    setState(() {
      if (_viewMonth == 1) {
        _viewYear--;
        _viewMonth = 12;
      } else {
        _viewMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_viewMonth == 12) {
        _viewYear++;
        _viewMonth = 1;
      } else {
        _viewMonth++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppTheme.cardDark : Colors.white;
    final primaryTextColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final primaryColor = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;
    final secondaryTextColor = AppTheme.textSecondaryLight;

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
      contentPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. 顶部控制栏：年与月切换选择按钮 + 左右切月按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 年月标题按钮 (点击切换 年视图 / 月视图)
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        SoundHapticService.instance.playSelectionClick();
                        setState(() {
                          _navMode = _navMode == CalendarNavMode.years
                              ? CalendarNavMode.days
                              : CalendarNavMode.years;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              '$_viewYear年',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: _navMode == CalendarNavMode.years ? primaryColor : primaryTextColor,
                              ),
                            ),
                            Icon(
                              _navMode == CalendarNavMode.years ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                              size: 20,
                              color: _navMode == CalendarNavMode.years ? primaryColor : secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        SoundHapticService.instance.playSelectionClick();
                        setState(() {
                          _navMode = _navMode == CalendarNavMode.months
                              ? CalendarNavMode.days
                              : CalendarNavMode.months;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              '$_viewMonth月',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: _navMode == CalendarNavMode.months ? primaryColor : primaryTextColor,
                              ),
                            ),
                            Icon(
                              _navMode == CalendarNavMode.months ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                              size: 20,
                              color: _navMode == CalendarNavMode.months ? primaryColor : secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 左右切月按键
                if (_navMode == CalendarNavMode.days)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: _prevMonth,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // 2. 主体展示视图 (年视图 / 月视图 / 日视图)
            if (_navMode == CalendarNavMode.years)
              _buildYearsGrid(primaryColor, primaryTextColor)
            else if (_navMode == CalendarNavMode.months)
              _buildMonthsGrid(primaryColor, primaryTextColor)
            else
              _buildDaysMatrix(primaryColor, primaryTextColor, secondaryTextColor, isDark),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // 3. 底部“回到今天”与“取消”快捷操作栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    final todayStr = TimeParserService.formatDate(DateTime.now());
                    SoundHapticService.instance.playSelectionClick();
                    widget.onDateSelected(todayStr);
                  },
                  icon: const Icon(Icons.today_rounded, size: 16),
                  label: const Text('回到今天', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 年份选择网格 (跨度当前年前后各 4 年)
  Widget _buildYearsGrid(Color primaryColor, Color textColor) {
    final nowYear = DateTime.now().year;
    final years = List.generate(12, (idx) => nowYear - 4 + idx);

    return SizedBox(
      height: 240,
      child: GridView.builder(
        gridDelegate: const dynamicDelegate(3, 1.8),
        itemCount: years.length,
        itemBuilder: (ctx, i) {
          final year = years[i];
          final isSelected = year == _viewYear;

          return InkWell(
            onTap: () {
              SoundHapticService.instance.playSelectionClick();
              setState(() {
                _viewYear = year;
                _navMode = CalendarNavMode.months; // 选完年自动切到月选择
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Text(
                '$year年',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : textColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 月份选择网格 (1~12月)
  Widget _buildMonthsGrid(Color primaryColor, Color textColor) {
    return SizedBox(
      height: 240,
      child: GridView.builder(
        gridDelegate: const dynamicDelegate(3, 1.8),
        itemCount: 12,
        itemBuilder: (ctx, i) {
          final month = i + 1;
          final isSelected = month == _viewMonth;

          return InkWell(
            onTap: () {
              SoundHapticService.instance.playSelectionClick();
              setState(() {
                _viewMonth = month;
                _navMode = CalendarNavMode.days; // 选完月切入日视图
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Text(
                '$month月',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : textColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 月度日历矩阵 (周一 ~ 周日 排列，带任务圆点标记)
  Widget _buildDaysMatrix(Color primaryColor, Color textColor, Color secondaryColor, bool isDark) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final firstDayOfMonth = DateTime(_viewYear, _viewMonth, 1);
    final daysInMonth = DateTime(_viewYear, _viewMonth + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday; // 1 (周一) ~ 7 (周日)
    final todayStr = TimeParserService.formatDate(DateTime.now());

    final totalCells = (startWeekday - 1) + daysInMonth;
    final totalRows = (totalCells / 7).ceil();

    return Column(
      children: [
        // 星期标头
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays.map((w) {
            final isWeekend = w == '六' || w == '日';
            return SizedBox(
              width: 38,
              child: Text(
                w,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isWeekend ? (isDark ? Colors.redAccent.shade100 : Colors.red.shade400) : secondaryColor,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),

        // 日期网格
        for (int r = 0; r < totalRows; r++)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (c) {
              final index = r * 7 + c;
              final dayNum = index - (startWeekday - 1) + 1;

              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox(width: 38, height: 38);
              }

              final dateStr = '$_viewYear-${_viewMonth.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
              final isSelected = dateStr == _selectedDate;
              final isToday = dateStr == todayStr;
              final hasTasks = widget.datesWithTasks.contains(dateStr);

              return InkWell(
                onTap: () {
                  SoundHapticService.instance.playSelectionClick();
                  widget.onDateSelected(dateStr);
                },
                borderRadius: BorderRadius.circular(19),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(color: primaryColor, width: 1.5)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isToday ? primaryColor : textColor),
                        ),
                      ),
                      if (hasTasks)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? AppTheme.badgeTimeDark : AppTheme.badgeTimeLight),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class dynamicDelegate extends SliverGridDelegateWithFixedCrossAxisCount {
  const dynamicDelegate(int crossAxisCount, double childAspectRatio)
      : super(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        );
}
