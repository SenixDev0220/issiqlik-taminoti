import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Teal glassmorphism design tokens. Surfaces are translucent white over the
/// mint gradient painted by AppBackground (see glass.dart).
class AppTheme {
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color success = Color(0xFF0E9F6E);
  static const Color warning = Color(0xFFB45309);
  static const Color error = Color(0xFFB91C1C);

  /// Fallback scaffold color; real screens paint AppBackground over it.
  static const Color surface = Color(0xFFEAF5F1);
  static const Color cardBg = Colors.white;

  /// Dark teal "ink" text colors.
  static const Color ink = Color(0xFF0B3B36);
  static const Color inkSoft = Color(0xFF33625B);
  static const Color inkFaint = Color(0xFF5E7F7A);

  /// Translucent glass surface + hairline border.
  static const Color glassFill = Color(0x99FFFFFF);
  static const Color glassBorder = Color(0xA6FFFFFF);

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
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.4,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: glassFill,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: glassBorder),
      ),
      shadowColor: const Color(0x141B5E55),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shadowColor: const Color(0x330F766E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size.fromHeight(52),
        backgroundColor: const Color(0x66FFFFFF),
        side: const BorderSide(color: Color(0xFF9CC8BF), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: error, width: 1.6),
      ),
      labelStyle: const TextStyle(color: inkSoft, fontSize: 14, fontWeight: FontWeight.w500),
      hintStyle: const TextStyle(color: inkFaint, fontSize: 14),
      prefixIconColor: inkSoft,
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: const BorderSide(color: glassBorder),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: inkSoft),
      backgroundColor: const Color(0x66FFFFFF),
      selectedColor: primary,
      secondarySelectedColor: primary,
      showCheckmark: false,
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0x260F766E),
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
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: ink,
      unselectedLabelColor: inkFaint,
      indicatorColor: primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      dividerColor: Color(0x260F766E),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFFF2FAF7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      showDragHandle: false,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFFF2FAF7),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: const Color(0xFF123F3A),
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: ink),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: ink),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF14453F)),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkSoft),
      bodyLarge: TextStyle(fontSize: 15, color: Color(0xFF1D4A44), height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF2C5751), height: 1.5),
      bodySmall: TextStyle(fontSize: 12, color: inkFaint, height: 1.4),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: const Color(0xFF2DD4BF),
      onPrimary: const Color(0xFF042F2E),
      secondary: accent,
      surface: const Color(0xFF0E1B19),
      onSurface: const Color(0xFFD7EBE6),
    ),
    scaffoldBackgroundColor: const Color(0xFF0E1B19),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFFD7EBE6),
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFFD7EBE6), letterSpacing: -0.4),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF14211F),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0x1AFFFFFF)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2DD4BF),
        foregroundColor: const Color(0xFF042F2E),
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF16302C),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0x33FFFFFF))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0x33FFFFFF))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2DD4BF), width: 1.6)),
      labelStyle: const TextStyle(color: Color(0xFF8FB5AE)),
      hintStyle: const TextStyle(color: Color(0xFF5E7F7A)),
      prefixIconColor: const Color(0xFF8FB5AE),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF14211F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Color(0xFFD7EBE6),
      unselectedLabelColor: Color(0xFF5E7F7A),
      indicatorColor: Color(0xFF2DD4BF),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF2DD4BF),
      foregroundColor: Color(0xFF042F2E),
      shape: CircleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: const Color(0xFF16302C),
    ),
  );
}
