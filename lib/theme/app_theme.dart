// Suggested location: lib/theme/app_theme.dart
import 'package:flutter/material.dart';

/// All colours live here so the whole app can be re-skinned in one place.
class AppColors {
  AppColors._();

  /// The app's signature colour.
  static const Color yellow = Color(0xFFFFD60A);

  /// A pale tint of the signature colour, used for track/background areas.
  static const Color yellowSoft = Color.fromARGB(255, 255, 206, 149);

  static const Color white = Colors.white;

  /// Near-black for text. Softer than pure #000 but still very high contrast.
  static const Color ink = Color(0xFF111111);

  static const Color inkMuted = Color.fromARGB(255, 249, 249, 249);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.yellow,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.yellow,
      onPrimary: AppColors.ink,
      secondary: AppColors.yellow,
      onSecondary: AppColors.ink,
      surface: AppColors.white,
      onSurface: AppColors.ink,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    final textTheme = base.textTheme
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .copyWith(
          // The constraint text ("Word must start with C").
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: AppColors.ink,
          ),
          // What the player types.
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.white,
      textTheme: textTheme,

      // The word box: solid yellow, no border until focused.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.yellow,
        hintStyle: const TextStyle(color: AppColors.inkMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.ink, width: 2.5),
        ),
      ),

      // Buttons: yellow with black text; clearly grey when disabled.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.yellow,
          foregroundColor: AppColors.ink,
          disabledBackgroundColor: const Color(0xFFE8E8E8),
          disabledForegroundColor: const Color(0xFFA0A0A0),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}