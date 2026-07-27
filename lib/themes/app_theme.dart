import 'package:flutter/material.dart';

/// Material Design 3 主题配置
class AppTheme {
  static ThemeData lightTheme() => _build(Brightness.light);
  static ThemeData darkTheme() => _build(Brightness.dark);
  static ThemeData lightFromScheme(ColorScheme s) => _build(Brightness.light, scheme: s);
  static ThemeData darkFromScheme(ColorScheme s) => _build(Brightness.dark, scheme: s);

  static ThemeData _build(Brightness brightness, {ColorScheme? scheme}) {
    final cs = scheme ?? ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface),
      ),

      cardTheme: CardTheme(
        elevation: 0,
        color: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant, width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: cs.surface,
        indicatorColor: cs.secondaryContainer,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1, space: 1),

      dialogTheme: DialogTheme(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      textTheme: TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.onSurface),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.onSurface),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: cs.onSurface),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
        bodyLarge: TextStyle(fontSize: 16, color: cs.onSurface),
        bodyMedium: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary),
      ),
    );
  }
}

/// ─── 向后兼容的 AppThemeColors ───
///
/// 这些静态值由 DynamicColorBuilder 回调更新。
/// 逐步迁移到 Theme.of(context).colorScheme 后移除本类。
class AppThemeColors {
  static Color _dayBg = const Color(0xFFFEF7FF);
  static Color _dayTitle = const Color(0xFF1C1B1F);
  static Color _daySubtitle = const Color(0xFF79747E);
  static Color _dayPrimary = const Color(0xFF6750A4);
  static Color _dayHighlight = const Color(0xFFE8DEF8);
  static Color _dayDivider = const Color(0xFFE7E0EC);
  static Color _nightBg = const Color(0xFF1C1B1F);
  static Color _nightTitle = const Color(0xFFE6E1E5);
  static Color _nightSubtitle = const Color(0xFF938F99);
  static Color _nightPrimary = const Color(0xFFD0BCFF);
  static Color _nightHighlight = const Color(0xFF4F378B);
  static Color _nightDivider = const Color(0xFF49454F);

  static void updateFromDynamic({required ColorScheme lightScheme, required ColorScheme darkScheme}) {
    _dayBg = lightScheme.surface;
    _dayTitle = lightScheme.onSurface;
    _daySubtitle = lightScheme.onSurfaceVariant;
    _dayPrimary = lightScheme.primary;
    _dayHighlight = lightScheme.surfaceContainerHighest;
    _dayDivider = lightScheme.outlineVariant;
    _nightBg = darkScheme.surface;
    _nightTitle = darkScheme.onSurface;
    _nightSubtitle = darkScheme.onSurfaceVariant;
    _nightPrimary = darkScheme.primary;
    _nightHighlight = darkScheme.surfaceContainerHighest;
    _nightDivider = darkScheme.outlineVariant;
  }

  static Color bg(bool n) => n ? _nightBg : _dayBg;
  static Color title(bool n) => n ? _nightTitle : _dayTitle;
  static Color subtitle(bool n) => n ? _nightSubtitle : _daySubtitle;
  static Color primary(bool n) => n ? _nightPrimary : _dayPrimary;
  static Color highlight(bool n) => n ? _nightHighlight : _dayHighlight;
  static Color divider(bool n) => n ? _nightDivider : _dayDivider;
  static Color overlay(bool n) => n ? const Color(0x80FFFFFF) : const Color(0x80000000);
  static Color filledBtn(bool n) => n ? _nightPrimary : _dayPrimary;
  static Color filledBtnText(bool n) => n ? _nightBg : _dayBg; // onPrimary ≈ bg
  static Color outlineBtnText(bool n) => n ? _nightPrimary : _dayPrimary;

  // 旧版兼容
  static Color get dayBg => _dayBg;
  static Color get nightBg => _nightBg;
  static Color get dayTitle => _dayTitle;
  static Color get nightTitle => _nightTitle;
  static Color get dayPrimary => _dayPrimary;
  static Color get nightPrimary => _nightPrimary;
  static Color get dayHighlight => _dayHighlight;
  static Color get nightHighlight => _nightHighlight;
  static Color get dayDivider => _dayDivider;
  static Color get nightDivider => _nightDivider;
}

/// ─── BuildContext 扩展 ───
extension ThemeColorsX on BuildContext {
  ColorScheme get $cs => Theme.of(this).colorScheme;
  bool get $night => Theme.of(this).brightness == Brightness.dark;
  Color get $bg => $cs.surface;
  Color get $title => $cs.onSurface;
  Color get $subtitle => $cs.onSurfaceVariant;
  Color get $primary => $cs.primary;
  Color get $highlight => $cs.surfaceContainerHighest;
  Color get $divider => $cs.outlineVariant;
  Color get $overlay => $night ? const Color(0x80FFFFFF) : const Color(0x80000000);
}
