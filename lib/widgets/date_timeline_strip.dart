import 'package:flutter/material.dart';
import '../services/time_parser_service.dart';
import '../theme/app_theme.dart';

/// 顶部横向日程日期胶囊条 (DateTimelineStrip)
/// 支持在昨天、今天、明天及未来两周内任意穿梭定位，查看那一天的全量时间流安排
class DateTimelineStrip extends StatelessWidget {
  final String selectedDate; // 当前选中的日期 YYYY-MM-DD
  final ValueChanged<String> onSelectDate;
  final Set<String> datesWithTasks; // 包含任务的日期集合，用于绘制状态小圆点

  const DateTimelineStrip({
    super.key,
    required this.selectedDate,
    required this.onSelectDate,
    this.datesWithTasks = const {},
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;
    final now = DateTime.now();
    final todayStr = TimeParserService.formatDate(now);

    // 默认展示前后 14 天的日期跨度 (可无限扩展)
    final daysList = List.generate(28, (index) {
      return now.add(Duration(days: index - 7)); // 从前 7 天到后 20 天
    });

    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        itemCount: daysList.length,
        itemBuilder: (context, index) {
          final dt = daysList[index];
          final dateStr = TimeParserService.formatDate(dt);
          final isSelected = dateStr == selectedDate;
          final isToday = dateStr == todayStr;
          final hasTasks = datesWithTasks.contains(dateStr);

          final weekdayName = _getWeekdayShort(dt.weekday);

          return GestureDetector(
            onTap: () => onSelectDate(dateStr),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              width: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor
                    : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isToday
                          ? primaryColor.withOpacity(0.5)
                          : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA))),
                  width: isToday ? 1.5 : 0.8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isToday ? '今天' : weekdayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : (isToday ? primaryColor : AppTheme.textSecondaryLight),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dt.day.toString(),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // 任务小标记圆点
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasTasks
                          ? (isSelected ? Colors.white : primaryColor)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getWeekdayShort(int weekday) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[weekday - 1];
  }
}
