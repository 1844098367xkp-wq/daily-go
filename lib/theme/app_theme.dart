import 'package:flutter/material.dart';

/// 《每日行》设计系统语义化色彩与主题规范 (对标 Things 3 与 iOS HIG)
class AppTheme {
  // ==================== Light Mode 色值 ====================
  static const Color primaryLight = Color(0xFF1D68BD); // 曜石靛蓝
  static const Color primaryTintLight = Color(0xFFF0F5FD); // 主色浅底胶囊
  static const Color backgroundLight = Color(0xFFF8F9FA); // 画布底色
  static const Color cardLight = Color(0xFFFFFFFF); // 卡片表面色
  static const Color sheetLight = Color(0xFFFFFFFF); // 底部弹窗表面色
  static const Color separatorLight = Color(0xFFE5E5EA); // 0.5pt 细分割线

  static const Color textPrimaryLight = Color(0xFF1C1C1E); // 92% 主黑
  static const Color textSecondaryLight = Color(0xFF8E8E93); // 中灰次文本
  static const Color textPlaceholderLight = Color(0xFFC7C7CC); // 占位符浅灰

  // ==================== Dark Mode 色值 ====================
  static const Color primaryDark = Color(0xFF3D82E2);
  static const Color primaryTintDark = Color(0xFF1A283D);
  static const Color backgroundDark = Color(0xFF000000); // 纯黑 OLED
  static const Color cardDark = Color(0xFF1C1C1E);
  static const Color sheetDark = Color(0xFF2C2C2E);
  static const Color separatorDark = Color(0xFF38383A);

  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF8E8E93);
  static const Color textPlaceholderDark = Color(0xFF48484A);

  // ==================== 低饱和功能状态色 (通用语义) ====================
  /// 顺延/待决状态 (暖砂琥珀) - 绝非刺眼红
  static const Color statusPostponedLight = Color(0xFFD97706);
  static const Color statusPostponedDark = Color(0xFFF59E0B);
  static const Color statusPostponedBgLight = Color(0xFFFFFBEB);
  static const Color statusPostponedBgDark = Color(0xFF292110);

  /// 专注状态 (鸢尾靛紫)
  static const Color statusFocusLight = Color(0xFF4F46E5);
  static const Color statusFocusDark = Color(0xFF6366F1);

  /// 沉淀归档 (岩板雾灰)
  static const Color statusArchivedLight = Color(0xFF64748B);
  static const Color statusArchivedDark = Color(0xFF94A3B8);

  /// 勾选完成 (柔和翡翠绿)
  static const Color statusSuccessLight = Color(0xFF22C55E);
  static const Color statusSuccessDark = Color(0xFF16A34A);

  // ==================== 间距与网格规范 (8pt Grid) ====================
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  static const double radiusSmall = 6.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 20.0;

  /// 构建浅色主题
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
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimaryLight),
      ),
      fontFamily: '.SF Pro Text',
    );
  }

  /// 构建深色主题 (OLED 纯黑)
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
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimaryDark),
      ),
      fontFamily: '.SF Pro Text',
    );
  }
}
