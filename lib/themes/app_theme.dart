import 'package:flutter/material.dart';

/// 动态颜色管理 — 支持 Android 12+ 自动取色（Material You）
/// 当系统支持动态取色时使用系统配色，否则回退到 Purle 基调
class AppThemeColors {
  // ---- 默认定值（深紫基调）----
  static const Color _dayBg = Color(0xFFFEF7FF);
  static const Color _dayTitle = Color(0xFF1C1B1F);
  static const Color _daySubtitle = Color(0xFF79747E);
  static const Color _dayPrimary = Color(0xFF6750A4);
  static const Color _dayHighlight = Color(0xFFE8DEF8);
  static const Color _dayDivider = Color(0xFFE7E0EC);
  static const Color _dayOverlay = Color(0x80000000);
  static const Color _dayFilledBtn = Color(0xFF6750A4);
  static const Color _dayFilledBtnText = Color(0xFFFFFFFF);
  static const Color _dayOutlineBtnText = Color(0xFF6750A4);

  static const Color _nightBg = Color(0xFF1C1B1F);
  static const Color _nightTitle = Color(0xFFE6E1E5);
  static const Color _nightSubtitle = Color(0xFF938F99);
  static const Color _nightPrimary = Color(0xFFD0BCFF);
  static const Color _nightHighlight = Color(0xFF4F378B);
  static const Color _nightDivider = Color(0xFF49454F);
  static const Color _nightOverlay = Color(0x80FFFFFF);
  static const Color _nightFilledBtn = Color(0xFFD0BCFF);
  static const Color _nightFilledBtnText = Color(0xFF1C1B1F);
  static const Color _nightOutlineBtnText = Color(0xFFD0BCFF);

  // ---- 可被替换的动态值 ----
  static Color _dayBgDyn = _dayBg;
  static Color _dayTitleDyn = _dayTitle;
  static Color _daySubtitleDyn = _daySubtitle;
  static Color _dayPrimaryDyn = _dayPrimary;
  static Color _dayHighlightDyn = _dayHighlight;
  static Color _dayDividerDyn = _dayDivider;
  static Color _dayOverlayDyn = _dayOverlay;
  static Color _dayFilledBtnDyn = _dayFilledBtn;
  static Color _dayFilledBtnTextDyn = _dayFilledBtnText;
  static Color _dayOutlineBtnTextDyn = _dayOutlineBtnText;

  static Color _nightBgDyn = _nightBg;
  static Color _nightTitleDyn = _nightTitle;
  static Color _nightSubtitleDyn = _nightSubtitle;
  static Color _nightPrimaryDyn = _nightPrimary;
  static Color _nightHighlightDyn = _nightHighlight;
  static Color _nightDividerDyn = _nightDivider;
  static Color _nightOverlayDyn = _nightOverlay;
  static Color _nightFilledBtnDyn = _nightFilledBtn;
  static Color _nightFilledBtnTextDyn = _nightFilledBtnText;
  static Color _nightOutlineBtnTextDyn = _nightOutlineBtnText;

  /// 根据系统的动态配色更新所有颜色值
  static void updateFromDynamic({
    required ColorScheme lightScheme,
    required ColorScheme darkScheme,
  }) {
    _dayBgDyn = lightScheme.surface;
    _dayTitleDyn = lightScheme.onSurface;
    _daySubtitleDyn = lightScheme.onSurfaceVariant;
    _dayPrimaryDyn = lightScheme.primary;
    _dayHighlightDyn = lightScheme.primaryContainer;
    _dayDividerDyn = lightScheme.outlineVariant;
    _dayOverlayDyn = const Color(0x80000000);
    _dayFilledBtnDyn = lightScheme.primary;
    _dayFilledBtnTextDyn = lightScheme.onPrimary;
    _dayOutlineBtnTextDyn = lightScheme.primary;

    _nightBgDyn = darkScheme.surface;
    _nightTitleDyn = darkScheme.onSurface;
    _nightSubtitleDyn = darkScheme.onSurfaceVariant;
    _nightPrimaryDyn = darkScheme.primary;
    _nightHighlightDyn = darkScheme.primaryContainer;
    _nightDividerDyn = darkScheme.outlineVariant;
    _nightOverlayDyn = const Color(0x80FFFFFF);
    _nightFilledBtnDyn = darkScheme.primary;
    _nightFilledBtnTextDyn = darkScheme.onPrimary;
    _nightOutlineBtnTextDyn = darkScheme.primary;
  }

  // ---- 公共访问器（保持向后兼容）----
  static Color bg(bool night) => night ? _nightBgDyn : _dayBgDyn;
  static Color title(bool night) => night ? _nightTitleDyn : _dayTitleDyn;
  static Color subtitle(bool night) => night ? _nightSubtitleDyn : _daySubtitleDyn;
  static Color primary(bool night) => night ? _nightPrimaryDyn : _dayPrimaryDyn;
  static Color highlight(bool night) => night ? _nightHighlightDyn : _dayHighlightDyn;
  static Color divider(bool night) => night ? _nightDividerDyn : _dayDividerDyn;
  static Color overlay(bool night) => night ? _nightOverlayDyn : _dayOverlayDyn;
  static Color filledBtn(bool night) => night ? _nightFilledBtnDyn : _dayFilledBtnDyn;
  static Color filledBtnText(bool night) => night ? _nightFilledBtnTextDyn : _dayFilledBtnTextDyn;
  static Color outlineBtnText(bool night) => night ? _nightOutlineBtnTextDyn : _dayOutlineBtnTextDyn;

  // ---- 向下兼容：个别文件仍使用 day/nightPrefix 形式 ----
  static Color get dayBg => _dayBgDyn;
  static Color get nightBg => _nightBgDyn;
  static Color get dayTitle => _dayTitleDyn;
  static Color get nightTitle => _nightTitleDyn;
  static Color get daySubtitle => _daySubtitleDyn;
  static Color get nightSubtitle => _nightSubtitleDyn;
  static Color get dayPrimary => _dayPrimaryDyn;
  static Color get nightPrimary => _nightPrimaryDyn;
  static Color get dayHighlight => _dayHighlightDyn;
  static Color get nightHighlight => _nightHighlightDyn;
  static Color get dayDivider => _dayDividerDyn;
  static Color get nightDivider => _nightDividerDyn;
  static Color get dayOverlay => _dayOverlayDyn;
  static Color get nightOverlay => _nightOverlayDyn;
  static Color get dayFilledBtn => _dayFilledBtnDyn;
  static Color get nightFilledBtn => _nightFilledBtnDyn;
  static Color get dayFilledBtnText => _dayFilledBtnTextDyn;
  static Color get nightFilledBtnText => _nightFilledBtnTextDyn;
  static Color get dayOutlineBtnText => _dayOutlineBtnTextDyn;
  static Color get nightOutlineBtnText => _nightOutlineBtnTextDyn;
}

/// 生成 ThemeData — 支持可选的动态配色
class AppTheme {
  /// 浅色主题
  static ThemeData lightTheme() => _buildTheme(Brightness.light);

  /// 深色主题
  static ThemeData darkTheme() => _buildTheme(Brightness.dark);

  /// 使用外部 ColorScheme（动态取色）
  static ThemeData lightFromScheme(ColorScheme scheme) =>
      _buildTheme(Brightness.light, scheme: scheme);

  static ThemeData darkFromScheme(ColorScheme scheme) =>
      _buildTheme(Brightness.dark, scheme: scheme);

  static ThemeData _buildTheme(Brightness brightness, {ColorScheme? scheme}) {
    final isDark = brightness == Brightness.dark;
    final cs = scheme ?? ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: brightness,
    );

    // 基础页面过渡动画用 M3 默认
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: isDark ? AppThemeColors._nightBgDyn : AppThemeColors._dayBgDyn,
      // 全局圆角
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // 按钮默认样式
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80)),
        ),
      ),
      // 更流畅的字体缩放
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.bold, color: cs.onSurface),
        headlineMedium: TextStyle(
          fontSize: 28, fontWeight: FontWeight.bold, color: cs.onSurface),
        titleLarge: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600, color: cs.onSurface),
        titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
        bodyLarge: TextStyle(fontSize: 16, color: cs.onSurface),
        bodyMedium: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
      ),
    );
  }
}
