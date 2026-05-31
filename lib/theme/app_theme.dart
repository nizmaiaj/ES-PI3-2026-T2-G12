import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF4C3BCF);
  static const _lightBackground = Color(0xFFF8F9FE);
  static const _darkBackground = Color(0xFF101116);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    );
    final outline = isDark ? const Color(0xFF3A3C47) : const Color(0xFFDADDE8);
    final surface = isDark ? const Color(0xFF181A22) : Colors.white;
    final surfaceContainer = isDark
        ? const Color(0xFF222532)
        : const Color(0xFFF1F2F8);

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: isDark ? _darkBackground : _lightBackground,
      cardColor: surface,
      dividerColor: outline,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF161821) : primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark
              ? const Color(0xFF3B3D46)
              : const Color(0xFFB8BBC8),
          disabledForegroundColor: isDark ? Colors.white54 : Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return surfaceContainer;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return colorScheme.onSurface;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: outline)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? const Color(0xFFCED2E0) : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return isDark ? const Color(0xFF4A4D5A) : Colors.grey.shade400;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF222532) : Colors.white,
        hintStyle: TextStyle(
          color: isDark ? Colors.white54 : Colors.grey.shade600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF292C38) : null,
        contentTextStyle: TextStyle(
          color: isDark ? Colors.white : null,
          fontSize: 14,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeColors(
          modalBackdrop: isDark
              ? const Color(0xFF07080C)
              : const Color(0xFF1F1F1F),
          elevatedSurface: surface,
          subtleSurface: surfaceContainer,
          panelBorder: isDark
              ? const Color(0xFF343746)
              : const Color(0xFFD8D1E0),
          mutedText: isDark ? const Color(0xFFC7CAD6) : const Color(0xFF62636B),
          faintText: isDark ? const Color(0xFF9498A6) : const Color(0xFF8A8C96),
          navSurface: isDark
              ? const Color(0xFF20232D)
              : const Color(0xFFEDEDED),
          shadow: isDark
              ? Colors.black.withValues(alpha: 0.36)
              : Colors.black.withValues(alpha: 0.18),
        ),
      ],
    );
  }
}

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.modalBackdrop,
    required this.elevatedSurface,
    required this.subtleSurface,
    required this.panelBorder,
    required this.mutedText,
    required this.faintText,
    required this.navSurface,
    required this.shadow,
  });

  final Color modalBackdrop;
  final Color elevatedSurface;
  final Color subtleSurface;
  final Color panelBorder;
  final Color mutedText;
  final Color faintText;
  final Color navSurface;
  final Color shadow;

  @override
  AppThemeColors copyWith({
    Color? modalBackdrop,
    Color? elevatedSurface,
    Color? subtleSurface,
    Color? panelBorder,
    Color? mutedText,
    Color? faintText,
    Color? navSurface,
    Color? shadow,
  }) {
    return AppThemeColors(
      modalBackdrop: modalBackdrop ?? this.modalBackdrop,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      subtleSurface: subtleSurface ?? this.subtleSurface,
      panelBorder: panelBorder ?? this.panelBorder,
      mutedText: mutedText ?? this.mutedText,
      faintText: faintText ?? this.faintText,
      navSurface: navSurface ?? this.navSurface,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;

    return AppThemeColors(
      modalBackdrop: Color.lerp(modalBackdrop, other.modalBackdrop, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      subtleSurface: Color.lerp(subtleSurface, other.subtleSurface, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      faintText: Color.lerp(faintText, other.faintText, t)!,
      navSurface: Color.lerp(navSurface, other.navSurface, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
