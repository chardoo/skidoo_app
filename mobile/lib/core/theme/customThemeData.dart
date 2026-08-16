import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/widgets/animations/app_animations.dart';

class Styles {
  static ThemeData get dark => themeData(true);
  static ThemeData get light => themeData(false);

  /// Bundled font family — see the `fonts:` block in pubspec.yaml. Declared
  /// as a plain string rather than via `GoogleFonts.poppins()` so the app
  /// never depends on a CDN fetch to render its own typeface.
  static const String fontFamily = 'Poppins';

  // Touch platforms get the slide-in transition that carries the edge
  // swipe-back gesture; desktop, which has no such gesture, keeps the fade.
  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: AppPageTransitionsBuilder(),
      TargetPlatform.iOS: AppPageTransitionsBuilder(),
      TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
      TargetPlatform.macOS: AppFadePageTransitionsBuilder(),
      TargetPlatform.windows: AppFadePageTransitionsBuilder(),
      TargetPlatform.linux: AppFadePageTransitionsBuilder(),
    },
  );

  static ThemeData themeData(bool isDarkTheme) {
    return ThemeData(
      pageTransitionsTheme: _pageTransitions,
      // The back arrow an AppBar draws for itself when a screen doesn't pass
      // `leading` resolves through here. Without it that implicit arrow is
      // Material's `arrow_back` on Android and a Cupertino chevron on iOS —
      // neither of which is the [AppBackButton] glyph the ~50 screens that do
      // pass `leading` are drawing. Roughly a third of the app's screens (all
      // of settings, notifications, cart, the search detail pages) rely on the
      // implicit button, so the app shipped two back arrows side by side.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => Icon(
          AppBackButton.icon,
          size: AppBackButton.defaultSize.sp,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        decoration: BoxDecoration(
            color: isDarkTheme ? Colors.black : Colors.white),
      ),
      timePickerTheme: TimePickerThemeData(
        hourMinuteTextColor: const Color(0xFF4CAF50),
        dayPeriodTextColor: const Color(0xFF4CAF50),
        dayPeriodColor: Colors.deepPurple,
        cancelButtonStyle: const ButtonStyle(),
        backgroundColor: isDarkTheme ? Colors.black : Colors.white,
        dialHandColor: Colors.green,
        dialBackgroundColor: isDarkTheme
            ? Colors.grey[800]
            : const Color.fromARGB(255, 172, 45, 45),
        entryModeIconColor: Colors.green,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
            color: isDarkTheme ? Colors.white54 : Colors.black54),
        // `border` only — deliberately no `focusedBorder`/`enabledBorder`.
        //
        // A field resolves its outline as `focusedBorder ?? border` when it has
        // focus, so a theme-level `focusedBorder` outranks whatever the call
        // site passed as `border`. Every field that draws its own container and
        // asks for `border: InputBorder.none` therefore grew a second grey
        // outline inside the first the moment the user tapped it — the search
        // bar, the shared SearchField, the ad-request form.
        //
        // The `focusedBorder` this replaces was a byte-for-byte copy of
        // `border`, so fields that don't override look exactly as they did:
        // every state now falls through to this one.
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: TextStyle(
            color: isDarkTheme
                ? Colors.white
                : const Color.fromARGB(255, 9, 10, 9)),
      ),
      fontFamily: fontFamily,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDarkTheme
            ? const Color(0xFF111110)
            : Colors.white,
        selectedItemColor:
            isDarkTheme ? Colors.white : const Color(0xFF1D9E75),
        // Darker grey on the light nav bar so unselected items meet AA contrast
        // (0xFF9A9AAA is ~2.5:1 on white).
        unselectedItemColor:
            isDarkTheme ? const Color(0xFF9A9AAA) : const Color(0xFF5E5E6B),
        selectedLabelStyle: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
      primaryColor: const Color(0xFF1D9E75),
      indicatorColor: isDarkTheme
          ? const Color(0xFF2C2C2A)
          : const Color.fromARGB(255, 195, 197, 201),
      hintColor: isDarkTheme
          ? const Color(0xFF1F1F1D)
          : const Color.fromARGB(255, 255, 255, 255),
      dialogTheme: DialogThemeData(
        backgroundColor:
            isDarkTheme ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      textTheme: _textTheme(isDarkTheme),
      focusColor: const Color(0xFF1D9E75),
      disabledColor: Colors.grey,
      cardColor: isDarkTheme ? const Color(0xFF1F1F1D) : Colors.white,
      canvasColor: isDarkTheme ? const Color(0xFF060A08) : Colors.grey[50],
      brightness: isDarkTheme ? Brightness.dark : Brightness.light,
      buttonTheme: ButtonThemeData(
        colorScheme: isDarkTheme
            ? const ColorScheme.dark()
            : const ColorScheme.light(),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDarkTheme ? Colors.white : Colors.black,
        titleTextStyle: TextStyle(
          color: isDarkTheme ? Colors.white : Colors.black,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
        iconTheme: IconThemeData(
          color: isDarkTheme ? Colors.white : Colors.black,
        ),
      ),
      extensions: [
        isDarkTheme ? AppThemeExtension.dark : AppThemeExtension.light,
      ],
      scaffoldBackgroundColor: isDarkTheme
          ? const Color(0xFF111110)
          : const Color(0xFFF7F7F2),
      colorScheme: ColorScheme(
        brightness: isDarkTheme ? Brightness.dark : Brightness.light,
        primary: isDarkTheme ? Colors.white : const Color(0xFF2C2C2A),
        secondaryContainer:
            isDarkTheme ? const Color(0xFF2B2929) : Colors.white,
        onPrimary: isDarkTheme ? Colors.grey : Colors.white,
        onSecondary: isDarkTheme ? Colors.white : Colors.black,
        secondary: const Color(0xFF42B546),
        error: isDarkTheme ? Colors.white : Colors.black,
        onError: isDarkTheme ? Colors.white : Colors.black,
        surface: isDarkTheme ? const Color(0xFF1F1F1D) : Colors.white,
        onSurface: isDarkTheme ? Colors.white : Colors.black,
      ),
    );
  }

  /// Material's [TextTheme] slots mapped onto [AppTypography].
  ///
  /// This block used to carry hand-picked values that contradicted Material's
  /// own semantics — `titleLarge` was 12sp/w300 while `headlineMedium` was
  /// 16sp and `displayLarge` 24sp, so any widget falling back to a Material
  /// default got a "large title" smaller and lighter than its own body text.
  /// No app code reads `Theme.of(context).textTheme` directly, but Material
  /// widgets do implicitly: AlertDialog titles use `titleLarge`, ListTile uses
  /// `bodyLarge`/`bodyMedium`, buttons use `labelLarge`. Those now inherit the
  /// same scale as the rest of the app instead of a parallel one.
  static TextTheme _textTheme(bool isDarkTheme) {
    final onSurface = isDarkTheme ? Colors.white : Colors.black;

    return TextTheme(
      displayLarge: AppTypography.display.copyWith(color: onSurface),
      displayMedium: AppTypography.display.copyWith(color: onSurface),
      displaySmall: AppTypography.display.copyWith(color: onSurface),
      headlineLarge: AppTypography.headline.copyWith(color: onSurface),
      headlineMedium: AppTypography.headline.copyWith(color: onSurface),
      headlineSmall: AppTypography.headline.copyWith(color: onSurface),
      titleLarge: AppTypography.title.copyWith(color: onSurface),
      titleMedium: AppTypography.subtitle.copyWith(color: onSurface),
      titleSmall: AppTypography.bodyLargeBold.copyWith(color: onSurface),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: onSurface),
      bodyMedium: AppTypography.body.copyWith(color: onSurface),
      bodySmall: AppTypography.caption.copyWith(color: onSurface),
      labelLarge: AppTypography.bodyLargeBold.copyWith(color: onSurface),
      labelMedium: AppTypography.label.copyWith(color: onSurface),
      labelSmall: AppTypography.micro.copyWith(color: onSurface),
    );
  }
}
