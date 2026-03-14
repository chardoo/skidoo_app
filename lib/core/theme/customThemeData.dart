import 'dart:ui';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Styles {
  static MaterialColor white = const MaterialColor(
    0xFFFFFFFF,
    <int, Color>{
      50: Color(0xFFFFFFFF),
      100: Color(0xFFFFFFFF),
      200: Color(0xFFFFFFFF),
      300: Color(0xFFFFFFFF),
      400: Color(0xFFFFFFFF),
      500: Color(0xFFFFFFFF),
      600: Color(0xFFFFFFFF),
      700: Color(0xFFFFFFFF),
      800: Color(0xFFFFFFFF),
      900: Color(0xFFFFFFFF),
    },
  );
  static ThemeData themeData(bool isDarkTheme, BuildContext context) {
    return ThemeData(
      dataTableTheme: DataTableThemeData(
       
        decoration: BoxDecoration(color: Colors.black)
      ),
      timePickerTheme: TimePickerThemeData(
         hourMinuteTextColor: Color(0xFF4CAF50), // Color of the hour and minute text - set to white.
          dayPeriodTextColor: const Color(0xFF4CAF50), // Color of the AM/PM text.
          dayPeriodColor: Colors.deepPurple,
       
        cancelButtonStyle: ButtonStyle(
                
                // side: MaterialStateProperty.all(
                //   BorderSide.lerp(
                //       BorderSide(
                //         style: BorderStyle.solid,
                //         color: Color(0xffe4e978),
                //         width: 10.0,
                //       ),
                //       BorderSide(
                //         style: BorderStyle.solid,
                //         color: Color(0xffe4e978),
                //         width: 10.0,
                //       ),
                //       10.0),
                // ),
              ),

    backgroundColor: isDarkTheme ? Colors.black : Colors.white,
    dialHandColor: Colors.green,
    dialBackgroundColor: isDarkTheme ? Colors.grey[800] : const Color.fromARGB(255, 172, 45, 45),
   
    entryModeIconColor: Colors.green,
    // Customize other aspects of the theme here...
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.black),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: TextStyle(
            color: isDarkTheme ? Colors.white : Color.fromARGB(255, 9, 10, 9)),
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Color.fromARGB(255, 10, 13, 17),
        selectedItemColor: Colors.white,
        unselectedItemColor: Color.fromARGB(255, 255, 255, 255),
        selectedLabelStyle: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
      primaryColor: Color(0xFFFF8303),
      indicatorColor: isDarkTheme
          ? const Color(0xff0E1D36)
          : const Color.fromARGB(255, 195, 197, 201),
      hintColor: isDarkTheme
          ? const Color(0xff280C0B)
          : const Color.fromARGB(255, 255, 255, 255),
      dialogTheme: DialogThemeData(
        backgroundColor: isDarkTheme ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      textTheme: TextTheme(
          titleLarge: TextStyle(
              fontWeight: FontWeight.w300,
              fontStyle: FontStyle.normal,
              color: isDarkTheme
                  ? const Color.fromARGB(255, 255, 255, 255)
                  : const Color.fromARGB(255, 0, 0, 0),
              fontSize: 12.sp),
          // googel loginButton

          headlineMedium: TextStyle(
              color: isDarkTheme
                  ? const Color.fromARGB(255, 255, 255, 255)
                  : const Color.fromARGB(255, 0, 0, 0),
              fontSize: 16.sp),
          headlineSmall: GoogleFonts.poppins(
              fontWeight: FontWeight.w300,
              fontStyle: FontStyle.normal,
              // letterSpacing: 1,
              fontSize: 14.sp,
              color: isDarkTheme
                  ? const Color.fromARGB(255, 255, 255, 255)
                  : const Color(0xff280C0B)),
          //card details theme
          displaySmall: GoogleFonts.poppins(
            fontFeatures: [const FontFeature.subscripts()],
            fontSize: 13.sp,
          ),
          displayMedium: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.normal,
              fontSize: 13.sp,
              color: isDarkTheme
                  ? const Color.fromARGB(255, 255, 255, 255)
                  : const Color(0xff280C0B)),
          displayLarge: GoogleFonts.karla(
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.normal,
              fontSize: 24.sp,
              color: isDarkTheme
                  ? const Color.fromARGB(255, 255, 255, 255)
                  : const Color.fromARGB(255, 0, 0, 0))),
      focusColor: Colors.orange,
      disabledColor: Colors.grey,
      cardColor: isDarkTheme ? const Color(0xFF151515) : Colors.white,
      canvasColor: isDarkTheme ? Colors.black : Colors.grey[50],
      brightness: isDarkTheme ? Brightness.dark : Brightness.light,
      buttonTheme: Theme.of(context).buttonTheme.copyWith(
          colorScheme: isDarkTheme
              ? const ColorScheme.dark()
              : const ColorScheme.light()),
      appBarTheme: AppBarTheme(
        
        elevation: 0.0,
        backgroundColor:
            isDarkTheme ? Color.fromARGB(255, 10, 13, 17) : Colors.grey[50],
      ),
     
      scaffoldBackgroundColor:
          isDarkTheme ? Color.fromARGB(255, 10, 13, 17) : const Color(0xFFF2F2F7),
      colorScheme: ColorScheme(
        brightness: isDarkTheme ? Brightness.dark : Brightness.light,
        primary: const Color.fromARGB(255, 255, 255, 255),

        secondaryContainer:
            isDarkTheme ? const Color(0xFF2B2929) : Colors.white,

        //opposite of  primary
        onPrimary: Colors.grey,
        onSecondary: isDarkTheme
            ? const Color.fromARGB(255, 255, 255, 255)
            : const Color.fromARGB(255, 0, 0, 0),
        secondary: const Color(0xFF42B546),
        error: isDarkTheme
            ? const Color.fromARGB(255, 255, 255, 255)
            : const Color.fromARGB(255, 0, 0, 0),
        onError: isDarkTheme
            ? const Color.fromARGB(255, 255, 255, 255)
            : const Color.fromARGB(255, 0, 0, 0),
        surface: isDarkTheme
            ? const Color.fromARGB(255, 255, 255, 255)
            : const Color.fromARGB(255, 0, 0, 0),
        background: isDarkTheme
            ? const Color.fromARGB(255, 255, 255, 255)
            : const Color.fromARGB(255, 0, 0, 0),
        onBackground: isDarkTheme
            ? const Color.fromARGB(255, 255, 255, 255)
            : const Color.fromARGB(255, 0, 0, 0),
        onSurface: isDarkTheme
            ? const Color.fromARGB(255, 255, 255, 255)
            : const Color.fromARGB(255, 0, 0, 0),
        // filter container style
      ),
    
    );
  }
}
