import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Named type scale. The app currently has 22+ distinct hand-picked
/// `fontSize` values with no shared vocabulary (including near-duplicates
/// like `13.sp` / `13.5.sp` / `12.5.sp` used for the same role in different
/// screens) — this is the single source of truth going forward.
///
/// Getters (not `const`) because `.sp` depends on the runtime screen size
/// via flutter_screenutil, same as every inline `TextStyle` in the app
/// today. Font family/color are intentionally left off — family comes from
/// `ThemeData.fontFamily` (Poppins, set once), and color varies by
/// light/dark theme, so callers apply it via `.copyWith(color: ext.xxx)`,
/// e.g. `AppTypography.body.copyWith(color: ext.greetingColor)`.
class AppTypography {
  const AppTypography._();

  /// 9sp / w600 — tiny badge text (unread counts, micro tags).
  static TextStyle get micro => TextStyle(
        fontSize: 9.sp,
        fontWeight: FontWeight.w600,
      );

  /// 11sp / w600 — small labels, pill tags, timestamps.
  static TextStyle get label => TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
      );

  /// 12sp / w500 — secondary/meta text (subtitles, hints).
  static TextStyle get caption => TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
      );

  /// 12sp / w700 — bold variant of [caption], e.g. small emphasized counts.
  static TextStyle get captionBold => TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
      );

  /// 13sp / w400 — default body text. The most common size in the app
  /// today (94 call sites at a hand-typed `13.sp`).
  static TextStyle get body => TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
      );

  /// 13sp / w700 — bold variant of [body], e.g. emphasized inline text.
  static TextStyle get bodyBold => TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
      );

  /// 14sp / w400 — slightly larger body text (form fields, list items).
  static TextStyle get bodyLarge => TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
      );

  /// 14sp / w600 — bold variant of [bodyLarge].
  static TextStyle get bodyLargeBold => TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
      );

  /// 15sp / w600 — card/list-item subtitles, secondary headings.
  static TextStyle get subtitle => TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
      );

  /// 17sp / w700 — page titles, app bar titles.
  static TextStyle get title => TextStyle(
        fontSize: 17.sp,
        fontWeight: FontWeight.w700,
      );

  /// 20sp / w800 — section headlines within a page.
  static TextStyle get headline => TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.w800,
      );

  /// 26sp / w700 — hero/display text (onboarding, empty states, splash).
  static TextStyle get display => TextStyle(
        fontSize: 26.sp,
        fontWeight: FontWeight.w700,
      );
}
