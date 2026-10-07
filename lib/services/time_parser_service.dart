/// 自然语言时间解析结果实体
class ParsedTaskInput {
  /// 清洗后的纯净任务标题
  final String title;

  /// 解析出的目标计划日期 (YYYY-MM-DD)，若未识别则默认为今天
  final String targetDate;

  /// 解析出的具体时刻 (HH:mm)，若未指定则为 null (表示随时处理)
  final String? timeSlot;

  /// 原始输入文本
  final String rawInput;

  /// 是否成功提取到显式时间意图
  final bool hasExplicitTime;

  const ParsedTaskInput({
    required this.title,
    required this.targetDate,
    this.timeSlot,
    required this.rawInput,
    required this.hasExplicitTime,
  });
}

/// 端侧轻量自然语言时间解析服务 (Zero-Network, <5ms 纯规则引擎)
class TimeParserService {
  /// 格式化 DateTime 为 'YYYY-MM-DD'
  static String formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 格式化时分为 'HH:mm'
  static String formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 核心解析方法：从单行自然语言输入中提取日期、时分，并剥离出纯净标题
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

    // 1. 匹配相对日期 (今天/明天/后天/大后天)
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

    // 2. 匹配星期 (周一~周日 / 星期一~星期日)
    final weekdayRegex = RegExp(r'(?:下周|下星期|本周|这周|周|星期)([一二三四五六日天七1-7])');
    final weekdayMatch = weekdayRegex.firstMatch(cleaned);
    if (weekdayMatch != null && !hasDateMatch) {
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

    // 3. 匹配时分 (如: 14:30 / 14点 / 下午3点半 / 晚上8点15)
    // 匹配时段前缀 (上午/下午/晚上/早晨/中午)
    String? period;
    final periodRegex = RegExp(r'(上午|早上|早晨|中午|下午|晚上|傍晚|深夜|今晚)');
    final periodMatch = periodRegex.firstMatch(cleaned);
    if (periodMatch != null) {
      period = periodMatch.group(0);
      cleaned = cleaned.replaceFirst(periodRegex, ' ');
    }

    // 3.1 格式一: 24小时制 HH:mm (如 14:30, 09:15)
    final standardTimeRegex = RegExp(r'(\d{1,2}):(\d{2})');
    final standardMatch = standardTimeRegex.firstMatch(cleaned);
    if (standardMatch != null) {
      hasTimeMatch = true;
      int hour = int.parse(standardMatch.group(1)!);
      final minute = int.parse(standardMatch.group(2)!);
      if (period != null && (period == '下午' || period == '晚上' || period == '傍晚') && hour < 12) {
        hour += 12;
      }
      timeSlot = formatTime(hour, minute);
      cleaned = cleaned.replaceFirst(standardTimeRegex, ' ');
    } else {
      // 3.2 格式二: 中文点刻 (如 3点, 3点半, 8点15分)
      final chineseTimeRegex = RegExp(r'(\d{1,2}|[一二两三四五六七八九十]+)点(?:(\d{1,2}|半|[一二两三四五六七八九十]+)(?:分)?)?');
      final chineseMatch = chineseTimeRegex.firstMatch(cleaned);
      if (chineseMatch != null) {
        hasTimeMatch = true;
        int hour = _parseChineseNumber(chineseMatch.group(1)!);
        int minute = 0;
        final minuteStr = chineseMatch.group(2);
        if (minuteStr != null) {
          if (minuteStr == '半') {
            minute = 30;
          } else {
            minute = _parseChineseNumber(minuteStr);
          }
        }

        // 根据时段修正下午/晚上的 12 小时制
        if (period != null && (period == '下午' || period == '晚上' || period == '傍晚' || period == '今晚') && hour < 12) {
          hour += 12;
        } else if (period != null && period == '中午' && hour < 11) {
          hour += 12;
        }
        timeSlot = formatTime(hour, minute);
        cleaned = cleaned.replaceFirst(chineseTimeRegex, ' ');
      }
    }

    // 4. 清理残留的多余空格与标点
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
