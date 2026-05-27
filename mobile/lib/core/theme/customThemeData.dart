import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:google_fonts/google_fonts.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

class Styles {
  static ThemeData get dark => themeData(true);
  static ThemeData get light => themeData(false);

  static ThemeData themeData(bool isDarkTheme) {
    return ThemeData(
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
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: TextStyle(
            color: isDarkTheme
                ? Colors.white
                : const Color.fromARGB(255, 9, 10, 9)),
      ),
      fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDarkTheme
            ? const Color.fromARGB(255, 10, 13, 17)
            : Colors.white,
        selectedItemColor:
            isDarkTheme ? Colors.white : const Color(0xFFF5A623),
        unselectedItemColor: const Color(0xFF9A9AAA),
        selectedLabelStyle: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
      primaryColor: const Color(0xFFFF8303),
      indicatorColor: isDarkTheme
          ? const Color(0xff0E1D36)
          : const Color.fromARGB(255, 195, 197, 201),
      hintColor: isDarkTheme
          ? const Color(0xff280C0B)
          : const Color.fromARGB(255, 255, 255, 255),
      dialogTheme: DialogThemeData(
        backgroundColor:
            isDarkTheme ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(
            fontWeight: FontWeight.w300,
            fontStyle: FontStyle.normal,
            color: isDarkTheme ? Colors.white : Colors.black,
            fontSize: 12.sp),
        headlineMedium: TextStyle(
            color: isDarkTheme ? Colors.white : Colors.black,
            fontSize: 16.sp),
        headlineSmall: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w300,
            fontStyle: FontStyle.normal,
            fontSize: 14.sp,
            color: isDarkTheme ? Colors.white : const Color(0xff280C0B)),
        displaySmall: GoogleFonts.spaceGrotesk(
          fontFeatures: [const FontFeature.subscripts()],
          fontSize: 13.sp,
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.normal,
            fontSize: 13.sp,
            color: isDarkTheme ? Colors.white : const Color(0xff280C0B)),
        displayLarge: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.normal,
            fontSize: 24.sp,
            color: isDarkTheme ? Colors.white : Colors.black),
      ),
      focusColor: Colors.orange,
      disabledColor: Colors.grey,
      cardColor: isDarkTheme ? const Color(0xFF151515) : Colors.white,
      canvasColor: isDarkTheme ? Colors.black : Colors.grey[50],
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
          fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
        ),
        iconTheme: IconThemeData(
          color: isDarkTheme ? Colors.white : Colors.black,
        ),
      ),
      extensions: [
        isDarkTheme ? AppThemeExtension.dark : AppThemeExtension.light,
      ],
      // ── Web: instant fade instead of mobile slide / zoom ─────────────────
      pageTransitionsTheme: kIsWeb
          ? PageTransitionsTheme(
              builders: {
                for (final p in TargetPlatform.values)
                  p: const _WebFadeTransitionBuilder(),
              },
            )
          : const PageTransitionsTheme(),
      scaffoldBackgroundColor: isDarkTheme
          ? const Color.fromARGB(255, 10, 13, 17)
          : const Color(0xFFF2F2F7),
      colorScheme: ColorScheme(
        brightness: isDarkTheme ? Brightness.dark : Brightness.light,
        primary: isDarkTheme ? Colors.white : const Color(0xFF1A1A2E),
        secondaryContainer:
            isDarkTheme ? const Color(0xFF2B2929) : Colors.white,
        onPrimary: isDarkTheme ? Colors.grey : Colors.white,
        onSecondary: isDarkTheme ? Colors.white : Colors.black,
        secondary: const Color(0xFF42B546),
        error: isDarkTheme ? Colors.white : Colors.black,
        onError: isDarkTheme ? Colors.white : Colors.black,
        surface: isDarkTheme ? const Color(0xFF1A1D24) : Colors.white,
        onSurface: isDarkTheme ? Colors.white : Colors.black,
      ),
    );
  }
}

// ── Web page transition: quick fade (no mobile-style slide) ───────────────────

class _WebFadeTransitionBuilder extends PageTransitionsBuilder {
  const _WebFadeTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ),
      child: child,
    );
  }
}
