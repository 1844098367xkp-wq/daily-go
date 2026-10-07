/// 自然语言时间解析结果实体
class ParsedTaskInput {
  final String title;
  final String targetDate; // YYYY-MM-DD
  final String? timeSlot; // HH:mm:ss 或 HH:mm
  final String rawInput;
  final bool hasExplicitTime;

  const ParsedTaskInput({
    required this.title,
    required this.targetDate,
    this.timeSlot,
    required this.rawInput,
    required this.hasExplicitTime,
  });
}

/// 端侧轻量自然语言时间解析服务 (Zero-Network, 支持精确到年月日时分秒)
class TimeParserService {
  /// 格式化 DateTime 为 'YYYY-MM-DD'
  static String formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 格式化时分秒为 'HH:mm:ss'
  static String formatTime(int hour, int minute, [int second = 0]) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    final s = second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// 核心解析方法：从单行自然语言输入中提取年月日时分秒，并剥离出纯净标题
  static ParsedTaskInput parse(String input, {DateTime? now}) {
    final baseTime = now ?? DateTime.now();
    String cleaned = input.trim();
    if (cleaned.isEmpty) {
      return ParsedTaskInput(
        title: '',
        targetDate: formatDate(baseTime),
        timeSlot: null,
        rawInput: input,
        hasExplicitTime: false,
      );
    }

    DateTime targetDate = baseTime;
    String? timeSlot;
    bool hasDateMatch = false;
    bool hasTimeMatch = false;

    // 1. 优先匹配绝对年月日 (如: 2026-10-08, 2026年10月8日, 10月8日, 10-08)
    final fullDateRegex = RegExp(r'(\d{4})[-/年](\d{1,2})[-/月](\d{1,2})[日号]?');
    final shortDateRegex = RegExp(r'(\d{1,2})[-/月](\d{1,2})[日号]?');
    final fullMatch = fullDateRegex.firstMatch(cleaned);
    final shortMatch = shortDateRegex.firstMatch(cleaned);

    if (fullMatch != null) {
      hasDateMatch = true;
      final year = int.parse(fullMatch.group(1)!);
      final month = int.parse(fullMatch.group(2)!);
      final day = int.parse(fullMatch.group(3)!);
      targetDate = DateTime(year, month, day);
      cleaned = cleaned.replaceFirst(fullDateRegex, ' ');
    } else if (shortMatch != null) {
      hasDateMatch = true;
      final month = int.parse(shortMatch.group(1)!);
      final day = int.parse(shortMatch.group(2)!);
      targetDate = DateTime(baseTime.year, month, day);
      cleaned = cleaned.replaceFirst(shortDateRegex, ' ');
    }

    // 2. 匹配相对日期 (今天/明天/后天/大后天)
    if (!hasDateMatch) {
      final relativeDateRegex = RegExp(r'(今天|今日|今晚|明天|明日|后天|大后天)');
      final relativeDateMatch = relativeDateRegex.firstMatch(cleaned);
      if (relativeDateMatch != null) {
        hasDateMatch = true;
        final matchStr = relativeDateMatch.group(0)!;
        if (matchStr == '今天' || matchStr == '今日' || matchStr == '今晚') {
          targetDate = baseTime;
        } else if (matchStr == '明天' || matchStr == '明日') {
          targetDate = baseTime.add(const Duration(days: 1));
        } else if (matchStr == '后天') {
          targetDate = baseTime.add(const Duration(days: 2));
        } else if (matchStr == '大后天') {
          targetDate = baseTime.add(const Duration(days: 3));
        }
        cleaned = cleaned.replaceFirst(relativeDateRegex, ' ');
      }
    }

    // 3. 匹配星期 (周一~周日 / 星期一~星期日)
    if (!hasDateMatch) {
      final weekdayRegex = RegExp(r'(?:下周|下星期|本周|这周|周|星期)([一二三四五六日天七1-7])');
      final weekdayMatch = weekdayRegex.firstMatch(cleaned);
      if (weekdayMatch != null) {
        hasDateMatch = true;
        final dayStr = weekdayMatch.group(1)!;
        final targetWeekday = _parseWeekdayNumber(dayStr);
        final isNextWeek = weekdayMatch.group(0)!.contains('下');

        int daysToAdd = (targetWeekday - baseTime.weekday) % 7;
        if (daysToAdd <= 0 || isNextWeek) {
          daysToAdd += 7;
        }
        targetDate = baseTime.add(Duration(days: daysToAdd));
        cleaned = cleaned.replaceFirst(weekdayRegex, ' ');
      }
    }

    // 4. 匹配时分秒 (时段前缀: 上午/下午/晚上/早晨/中午)
    String? period;
    final periodRegex = RegExp(r'(上午|早上|早晨|中午|下午|晚上|傍晚|深夜|今晚)');
    final periodMatch = periodRegex.firstMatch(cleaned);
    if (periodMatch != null) {
      period = periodMatch.group(0);
      cleaned = cleaned.replaceFirst(periodRegex, ' ');
    }

    // 4.1 格式一: 精确到秒的数字格式 HH:mm:ss (如 14:30:15)
    final secTimeRegex = RegExp(r'(\d{1,2}):(\d{2}):(\d{2})');
    final secMatch = secTimeRegex.firstMatch(cleaned);
    if (secMatch != null) {
      hasTimeMatch = true;
      int hour = int.parse(secMatch.group(1)!);
      final minute = int.parse(secMatch.group(2)!);
      final second = int.parse(secMatch.group(3)!);
      if (period != null && (period == '下午' || period == '晚上' || period == '傍晚' || period == '今晚') && hour < 12) {
        hour += 12;
      }
      timeSlot = formatTime(hour, minute, second);
      cleaned = cleaned.replaceFirst(secTimeRegex, ' ');
    } else {
      // 4.2 格式二: 标准 24 小时制 HH:mm (如 14:30, 09:15)
      final standardTimeRegex = RegExp(r'(\d{1,2}):(\d{2})');
      final standardMatch = standardTimeRegex.firstMatch(cleaned);
      if (standardMatch != null) {
        hasTimeMatch = true;
        int hour = int.parse(standardMatch.group(1)!);
        final minute = int.parse(standardMatch.group(2)!);
        if (period != null && (period == '下午' || period == '晚上' || period == '傍晚' || period == '今晚') && hour < 12) {
          hour += 12;
        }
        timeSlot = formatTime(hour, minute, 0);
        cleaned = cleaned.replaceFirst(standardTimeRegex, ' ');
      } else {
        // 4.3 格式三: 中文点刻，含秒 (如 3点半, 8点15分30秒)
        final chineseSecRegex = RegExp(r'(\d{1,2}|[一二两三四五六七八九十]+)点(?:(\d{1,2}|半|[一二两三四五六七八九十]+)(?:分)?)?(?:(\d{1,2}|[一二两三四五六七八九十]+)(?:秒)?)?');
        final chineseMatch = chineseSecRegex.firstMatch(cleaned);
        if (chineseMatch != null) {
          hasTimeMatch = true;
          int hour = _parseChineseNumber(chineseMatch.group(1)!);
          int minute = 0;
          int second = 0;

          final minuteStr = chineseMatch.group(2);
          if (minuteStr != null) {
            if (minuteStr == '半') {
              minute = 30;
            } else {
              minute = _parseChineseNumber(minuteStr);
            }
          }
          final secStr = chineseMatch.group(3);
          if (secStr != null) {
            second = _parseChineseNumber(secStr);
          }

          if (period != null && (period == '下午' || period == '晚上' || period == '傍晚' || period == '今晚') && hour < 12) {
            hour += 12;
          } else if (period != null && period == '中午' && hour < 11) {
            hour += 12;
          }
          timeSlot = formatTime(hour, minute, second);
          cleaned = cleaned.replaceFirst(chineseSecRegex, ' ');
        }
      }
    }

    final finalTitle = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return ParsedTaskInput(
      title: finalTitle.isEmpty ? input.trim() : finalTitle,
      targetDate: formatDate(targetDate),
      timeSlot: timeSlot,
      rawInput: input,
      hasExplicitTime: hasDateMatch || hasTimeMatch,
    );
  }

  static int _parseWeekdayNumber(String s) {
    switch (s) {
      case '一': case '1': return 1;
      case '二': case '2': return 2;
      case '三': case '3': return 3;
      case '四': case '4': return 4;
      case '五': case '5': return 5;
      case '六': case '6': return 6;
      case '日': case '天': case '七': case '7': return 7;
      default: return 1;
    }
  }

  static int _parseChineseNumber(String s) {
    final parsedInt = int.tryParse(s);
    if (parsedInt != null) return parsedInt;
    switch (s) {
      case '一': return 1;
      case '二': case '两': return 2;
      case '三': return 3;
      case '四': return 4;
      case '五': return 5;
      case '六': return 6;
      case '七': return 7;
      case '八': return 8;
      case '九': return 9;
      case '十': return 10;
      default: return 0;
    }
  }
}
