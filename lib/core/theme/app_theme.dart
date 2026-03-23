import 'package:flutter/material.dart';

abstract class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF1B5278),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD0E8F8),
      onPrimaryContainer: Color(0xFF0A2E4A),
      secondary: Color(0xFF4A90B8),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD8EEFA),
      onSecondaryContainer: Color(0xFF0A2E4A),
      tertiary: Color(0xFF5E8DAE),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD8EEF8),
      onTertiaryContainer: Color(0xFF0A2E4A),
      error: Color(0xFF9F403D),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFEDF2F7),
      onSurface: Color(0xFF1A2B3C),
      surfaceContainerHighest: Color(0xFFCDD8E2),
      surfaceContainerHigh: Color(0xFFD8E3EC),
      surfaceContainer: Color(0xFFE2EBF3),
      surfaceContainerLow: Color(0xFFEBF2F8),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      onSurfaceVariant: Color(0xFF6A8090),
      outline: Color(0xFFAABBC8),
      outlineVariant: Color(0xFFCCD8E0),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF1A2B3C),
      onInverseSurface: Color(0xFFEDF2F7),
      inversePrimary: Color(0xFF5BB8E8),
    );
    return _buildTheme(scheme);
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF5BB8E8),
      onPrimary: Color(0xFF001828),
      primaryContainer: Color(0xFF1A3A55),
      onPrimaryContainer: Color(0xFFB8DEEF),
      secondary: Color(0xFF4A90B8),
      onSecondary: Color(0xFF001828),
      secondaryContainer: Color(0xFF152535),
      onSecondaryContainer: Color(0xFFB8DEEF),
      tertiary: Color(0xFF5E8DAE),
      onTertiary: Color(0xFF001828),
      tertiaryContainer: Color(0xFF152535),
      onTertiaryContainer: Color(0xFFB8DEEF),
      error: Color(0xFFFF897D),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF070C16),
      onSurface: Color(0xFFE4EEFA),
      surfaceContainerHighest: Color(0xFF1E2D3F),
      surfaceContainerHigh: Color(0xFF172437),
      surfaceContainer: Color(0xFF111D2E),
      surfaceContainerLow: Color(0xFF0D1725),
      surfaceContainerLowest: Color(0xFF0A1320),
      onSurfaceVariant: Color(0xFF7A9AB0),
      outline: Color(0xFF3A5060),
      outlineVariant: Color(0xFF1E2D3F),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE4EEFA),
      onInverseSurface: Color(0xFF070C16),
      inversePrimary: Color(0xFF1B5278),
    );
    return _buildTheme(scheme);
  }

  static ThemeData _buildTheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final fillColor =
        isDark ? const Color(0xFF141F30) : const Color(0xFFE4EDF6);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF0F1828) : Colors.white,
        elevation: isDark ? 0 : 2,
        shadowColor: scheme.shadow.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.error.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF0A1322) : Colors.white,
        indicatorColor: isDark ? const Color(0xFF1A3A55) : const Color(0xFFD0E8F8),
        height: 64,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF1E2D3F) : const Color(0xFFE5EDF4),
        space: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
