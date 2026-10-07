import 'package:flutter/material.dart';

/// 《每日行》精美设计系统 (深度对标 Things 3 与 Apple HIG 顶级质感)
class AppTheme {
  // ==================== 核心色彩 Tokens ====================
  static const Color primaryLight = Color(0xFF2563EB); // 皇家靛蓝 (更有质感)
  static const Color primaryTintLight = Color(0xFFEFF6FF);
  static const Color backgroundLight = Color(0xFFF8FAFC); // 珠光轻灰画布
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color sheetLight = Color(0xFFFFFFFF);
  static const Color separatorLight = Color(0xFFF1F5F9);

  static const Color textPrimaryLight = Color(0xFF0F172A); // 深岩黑，极高对比度
  static const Color textSecondaryLight = Color(0xFF64748B); // 优雅石板灰
  static const Color textPlaceholderLight = Color(0xFF94A3B8);

  // ==================== Dark Mode 色值 (OLED 纯黑 + 阶梯微光) ====================
  static const Color primaryDark = Color(0xFF3B82F6);
  static const Color primaryTintDark = Color(0xFF1E293B);
  static const Color backgroundDark = Color(0xFF090D16); // 深邃夜空黑
  static const Color cardDark = Color(0xFF131B2E); // 优雅夜空卡片
  static const Color sheetDark = Color(0xFF1E293B);
  static const Color separatorDark = Color(0xFF1E293B);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textPlaceholderDark = Color(0xFF64748B);

  // ==================== 语义化彩色图标徽标底色 (Icon Badges) ====================
  /// 闹钟/提醒徽标色 (暖阳金)
  static const Color badgeAlarmLight = Color(0xFFF59E0B);
  static const Color badgeAlarmBgLight = Color(0xFFFEF3C7);
  static const Color badgeAlarmDark = Color(0xFFFBBF24);
  static const Color badgeAlarmBgDark = Color(0xFF451A03);

  /// 时间/定时徽标色 (晨曦蓝)
  static const Color badgeTimeLight = Color(0xFF3B82F6);
  static const Color badgeTimeBgLight = Color(0xFFDBEAFE);
  static const Color badgeTimeDark = Color(0xFF60A5FA);
  static const Color badgeTimeBgDark = Color(0xFF1E3A8A);

  /// 灵感备忘徽标色 (紫罗兰)
  static const Color badgeIdeaLight = Color(0xFF8B5CF6);
  static const Color badgeIdeaBgLight = Color(0xFFEDE9FE);
  static const Color badgeIdeaDark = Color(0xFFA78BFA);
  static const Color badgeIdeaBgDark = Color(0xFF3B0764);

  /// 完成/健康徽标色 (翡翠绿)
  static const Color badgeSuccessLight = Color(0xFF10B981);
  static const Color badgeSuccessBgLight = Color(0xFFD1FAE5);
  static const Color badgeSuccessDark = Color(0xFF34D399);
  static const Color badgeSuccessBgDark = Color(0xFF064E3B);

  // ==================== 低饱和功能状态色 ====================
  static const Color statusPostponedLight = Color(0xFFD97706);
  static const Color statusPostponedDark = Color(0xFFF59E0B);
  static const Color statusPostponedBgLight = Color(0xFFFFFBEB);
  static const Color statusPostponedBgDark = Color(0xFF292110);

  static const Color statusSuccessLight = Color(0xFF10B981);
  static const Color statusSuccessDark = Color(0xFF059669);

  // ==================== 间距与圆角 ====================
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;

  /// 优雅卡片微阴影
  static List<BoxShadow> cardShadow(bool isDark) {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF64748B).withOpacity(0.06),
        blurRadius: 18,
        spreadRadius: 0,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: const Color(0xFF64748B).withOpacity(0.04),
        blurRadius: 4,
        spreadRadius: 0,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: backgroundLight,
      cardColor: cardLight,
      dividerColor: separatorLight,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        surface: cardLight,
        onSurface: textPrimaryLight,
        outline: separatorLight,
      ),
      fontFamily: '.SF Pro Text',
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryDark,
      scaffoldBackgroundColor: backgroundDark,
      cardColor: cardDark,
      dividerColor: separatorDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        surface: cardDark,
        onSurface: textPrimaryDark,
        outline: separatorDark,
      ),
      fontFamily: '.SF Pro Text',
    );
  }
}
