import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cool indigo and cyan tokens for the app's luminous glass surfaces.
class AppTheme {
  static const Color primary = Color(0xFF4658D8);
  static const Color accent = Color(0xFF20B8D2);
  static const Color success = Color(0xFF168C79);
  static const Color warning = Color(0xFFB96A18);
  static const Color error = Color(0xFFC3425A);

  /// Fallback scaffold color; real screens paint AppBackground over it.
  static const Color surface = Color(0xFFF0F3FC);
  static const Color cardBg = Colors.white;

  /// Deep indigo text colors.
  static const Color ink = Color(0xFF202747);
  static const Color inkSoft = Color(0xFF505B7A);
  static const Color inkFaint = Color(0xFF77809A);

  /// Translucent glass surface + hairline border.
  static const Color glassFill = Color(0xC9FFFFFF);
  static const Color glassBorder = Color(0xDFFFFFFF);

  static const Color darkSurface = Color(0xFF14182A);
  static const Color darkGlassFill = Color(0xDD20253A);
  static const Color darkGlassBorder = Color(0x33B8C0E3);
  static const Color darkInk = Color(0xFFE7EAF8);
  static const Color darkInkSoft = Color(0xFFB8C0E3);
  static const Color darkInkFaint = Color(0xFF9BA5C5);
  static const Color darkPrimary = Color(0xFF9CA8FF);

  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color inkFor(BuildContext context) => isDark(context) ? darkInk : ink;
  static Color inkSoftFor(BuildContext context) => isDark(context) ? darkInkSoft : inkSoft;
  static Color inkFaintFor(BuildContext context) => isDark(context) ? darkInkFaint : inkFaint;
  static Color glassFillFor(BuildContext context) => isDark(context) ? darkGlassFill : glassFill;
  static Color glassBorderFor(BuildContext context) => isDark(context) ? darkGlassBorder : glassBorder;

  /// Preserve the light palette while keeping semantic accents readable at night.
  static Color adaptiveColor(BuildContext context, Color color) {
    if (!isDark(context)) return color;
    return switch (color) {
      primary => darkPrimary,
      ink => darkInk,
      inkSoft => darkInkSoft,
      inkFaint => darkInkFaint,
      success => const Color(0xFF66D7BC),
      warning => const Color(0xFFE7B478),
      error => const Color(0xFFFF91A5),
      _ => color,
    };
  }

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      error: error,
      surface: surface,
      onSurface: ink,
    ),
    scaffoldBackgroundColor: surface,
    splashFactory: InkRipple.splashFactory,

    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -0.4,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: glassFill,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: glassBorder),
      ),
      shadowColor: const Color(0x144658D8),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shadowColor: const Color(0x334658D8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size.fromHeight(52),
        backgroundColor: const Color(0x66FFFFFF),
        side: const BorderSide(color: Color(0xFFB7C2EE), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x80FFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: error, width: 1.6),
      ),
      labelStyle: const TextStyle(
        color: inkSoft,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: inkFaint, fontSize: 14),
      prefixIconColor: inkSoft,
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: const BorderSide(color: glassBorder),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: inkSoft,
      ),
      backgroundColor: const Color(0x66FFFFFF),
      selectedColor: primary,
      secondarySelectedColor: primary,
      showCheckmark: false,
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0x244658D8),
      thickness: 1,
      space: 1,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      iconColor: primary,
      textColor: ink,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: ink,
      unselectedLabelColor: inkFaint,
      indicatorColor: primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      dividerColor: Color(0x244658D8),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFFF4F6FD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: false,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFFF4F6FD),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: const Color(0xFF242E58),
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF303B65),
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: inkSoft,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: Color(0xFF394462), height: 1.5),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Color(0xFF505B78),
        height: 1.5,
      ),
      bodySmall: TextStyle(fontSize: 12, color: inkFaint, height: 1.4),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: const Color(0xFF1D2552),
      secondary: accent,
      error: const Color(0xFFFF91A5),
      surface: darkSurface,
      onSurface: darkInk,
      onSurfaceVariant: darkInkSoft,
    ),
    scaffoldBackgroundColor: darkSurface,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: lightTheme.appBarTheme.copyWith(
      foregroundColor: darkInk,
      titleTextStyle: lightTheme.appBarTheme.titleTextStyle?.copyWith(color: darkInk),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    cardTheme: lightTheme.cardTheme.copyWith(
      color: darkGlassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: darkGlassBorder),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: lightTheme.elevatedButtonTheme.style?.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? darkInk.withValues(alpha: 0.12) : darkPrimary),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? darkInk.withValues(alpha: 0.38) : const Color(0xFF1D2552)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: lightTheme.outlinedButtonTheme.style?.copyWith(
        foregroundColor: const WidgetStatePropertyAll(darkPrimary),
        backgroundColor: const WidgetStatePropertyAll(Color(0x44252B42)),
        side: const WidgetStatePropertyAll(BorderSide(color: darkGlassBorder, width: 1.2)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: darkPrimary),
    ),
    inputDecorationTheme: lightTheme.inputDecorationTheme.copyWith(
      fillColor: const Color(0xFF252B42),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: darkGlassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: darkGlassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: darkPrimary, width: 1.6),
      ),
      labelStyle: const TextStyle(color: darkInkSoft, fontSize: 14),
      hintStyle: const TextStyle(color: darkInkFaint, fontSize: 14),
      prefixIconColor: darkInkSoft,
    ),
    chipTheme: lightTheme.chipTheme.copyWith(
      backgroundColor: darkGlassFill,
      side: const BorderSide(color: darkGlassBorder),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkInkSoft),
    ),
    dividerTheme: const DividerThemeData(color: darkGlassBorder, thickness: 1, space: 1),
    listTileTheme: lightTheme.listTileTheme.copyWith(iconColor: darkPrimary, textColor: darkInk),
    segmentedButtonTheme: lightTheme.segmentedButtonTheme,
    bottomSheetTheme: lightTheme.bottomSheetTheme.copyWith(backgroundColor: const Color(0xFF20253A)),
    dialogTheme: lightTheme.dialogTheme.copyWith(
      backgroundColor: const Color(0xFF20253A),
      titleTextStyle: lightTheme.dialogTheme.titleTextStyle?.copyWith(color: darkInk),
    ),
    tabBarTheme: lightTheme.tabBarTheme.copyWith(
      labelColor: darkInk,
      unselectedLabelColor: darkInkFaint,
      indicatorColor: darkPrimary,
      dividerColor: darkGlassBorder,
    ),
    floatingActionButtonTheme: lightTheme.floatingActionButtonTheme.copyWith(
      backgroundColor: darkPrimary,
      foregroundColor: const Color(0xFF1D2552),
    ),
    snackBarTheme: lightTheme.snackBarTheme.copyWith(
      backgroundColor: const Color(0xFF252B42),
      contentTextStyle: const TextStyle(color: darkInk),
    ),
    textTheme: lightTheme.textTheme.apply(bodyColor: darkInk, displayColor: darkInk),
  );
}
