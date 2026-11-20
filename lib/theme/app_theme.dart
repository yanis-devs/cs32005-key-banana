import 'package:flutter/material.dart';

/// K-Banana palette. Every colour in the app comes from here, so the whole
/// app can be re-skinned in one place.
class AppColors {
  AppColors._();

  /// Page background.
  static const Color cream = Color(0xFFFFF8E9);

  /// Secondary cards, progress track, secondary buttons.
  static const Color yellowSoft = Color(0xFFFFF0C2);

  /// Main buttons and highlights.
  static const Color yellow = Color(0xFFFFD21F);

  /// Soft decorative outlines (1-2dp). Too light to be the only cue for an
  /// interactive control, so the text box switches to [ink] when focused.
  static const Color gold = Color(0xFFFFB928);

  /// Primary text and icons (dark chocolate brown).
  static const Color ink = Color(0xFF48250F);

  /// Secondary text.
  static const Color inkMuted = Color(0xFF80664F);

  /// Text input fill.
  static const Color white = Colors.white;

  /// Green used for valid results. Always paired with an icon and text, never
  /// colour alone. Above 4.5:1 contrast on cream.
  static const Color valid = Color(0xFF2E7D32);

  /// Red used for invalid results. Same rules as [valid].
  static const Color invalid = Color(0xFFC62828);
}

/// The app's Material theme: fonts, text styles, and the look of buttons,
/// cards, dialogs and other shared components. Built from [AppColors].
class AppTheme {
  AppTheme._();

  /// Font used throughout the app.
  static const String fontFamily = 'Nunito';

  /// Corner radius for cards and the word box.
  static const double _cardRadius = 24;

  /// Corner radius for dialogs and bottom sheets.
  static const double _sheetRadius = 28;

  /// Soft brown shadow used on buttons and cards.
  static const Color _shadow = Color(0x3348250F);

  /// Rounded outline for the word box, in the given [color] and [width].
  static OutlineInputBorder _inputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_cardRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// The light theme, which is the only theme the app uses.
  static ThemeData get light {
    // Start from a seeded scheme, then override the colours that matter so
    // the result matches the palette exactly.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.yellow,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.yellow,
          onPrimary: AppColors.ink,
          secondary: AppColors.gold,
          onSecondary: AppColors.ink,
          surface: AppColors.cream,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.inkMuted,
          outline: AppColors.gold,
          error: AppColors.invalid,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );

    // Apply the brown text colour to every text style.
    final applied = base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    final textTheme = applied.copyWith(
      // Final score.
      displayMedium: applied.displayMedium?.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w800,
      ),
      // What the player types.
      displaySmall: applied.displaySmall?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
      ),
      // Headings and the constraint text ("Word must start with C").
      headlineMedium: applied.headlineMedium?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
      titleLarge: applied.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: applied.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: applied.bodyLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: applied.bodyMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: applied.bodySmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      // Button labels.
      labelLarge: applied.labelLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );

    // Shared button shape and sizing.
    const pill = StadiumBorder();
    const buttonPadding = EdgeInsets.symmetric(horizontal: 40, vertical: 16);
    const buttonMinSize = Size(0, 56); // comfortable touch target

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.ink),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
      ),

      // The word box: white, golden border, brown border when focused.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        hintStyle: const TextStyle(color: AppColors.inkMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 20,
        ),
        border: _inputBorder(AppColors.gold, 2),
        enabledBorder: _inputBorder(AppColors.gold, 2),
        focusedBorder: _inputBorder(AppColors.ink, 2.5),
      ),

      // Main button: banana yellow, brown label, pill shape.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.yellow,
          foregroundColor: AppColors.ink,
          disabledBackgroundColor: const Color(0xFFEDE3CF),
          disabledForegroundColor: const Color(0xFF9C8B78),
          elevation: 2,
          shadowColor: _shadow,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Secondary button (Practice, My stats): pale fill, golden outline.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.yellowSoft,
          foregroundColor: AppColors.ink,
          disabledForegroundColor: const Color(0xFF9C8B78),
          side: const BorderSide(color: AppColors.gold, width: 2),
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Dialog buttons ("Keep playing", "Quit") and "Try again".
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(48, 48),
          textStyle: textTheme.titleMedium,
        ),
      ),

      // Round cards on the results screen: pale yellow, soft golden outline.
      cardTheme: CardThemeData(
        color: AppColors.yellowSoft,
        elevation: 1,
        shadowColor: _shadow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),

      // Quit confirmation dialog.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_sheetRadius),
          side: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
      ),

      // Definition sheet.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cream,
        modalBackgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.inkMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_sheetRadius),
          ),
        ),
      ),

      // Messages such as "already played today".
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: AppColors.cream,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Semi-transparent gold line (0x80 is about 50% opacity).
      dividerTheme: const DividerThemeData(
        color: Color(0x80FFB928),
        thickness: 1.5,
        space: 24,
      ),

      // Brown spinner: banana yellow would be nearly invisible on cream.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.yellowSoft,
      ),
    );
  }
}
