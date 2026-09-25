import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The type scale, and the app's copy of the design file's typography
/// variables.
///
/// Figma names seven sizes (`typography/12` … `typography/24`), four weights
/// and three line heights. Those are [xs] … [xxl], [light] … [bold] and
/// [tight] / [normal] / [loose] below — same numbers, same steps, so a value
/// read off the file has somewhere to land here without a conversion in
/// anybody's head. The app had drifted to 22 distinct hand-picked sizes and a
/// weight vocabulary of its own (w600, w800, w900 — none of which the file
/// has), which is what made the brand face read as nearly-right.
///
/// The role tiers below — [caption], [body], [title] and friends — are that
/// scale applied to jobs. Prefer them to a hand-typed `TextStyle`: an inline
/// style is how a size lands between two steps and how a header quietly gets
/// body type.
///
/// Sizes are getters, not constants, because `.sp` reads the runtime screen
/// through flutter_screenutil.
///
/// Colour is deliberately absent everywhere: it varies by theme, so callers
/// apply it via `.copyWith(color: ext.xxx)` —
/// `AppTypography.body.copyWith(color: ext.greetingColor)`.
class AppTypography {
  const AppTypography._();

  /// The two brand typefaces — see the `fonts:` block in pubspec.yaml.
  /// Declared as plain strings rather than via `GoogleFonts.xxx()` so the app
  /// never depends on a CDN fetch to render its own typeface.
  ///
  /// [bodyFontFamily] is the app-wide default, set once as
  /// `ThemeData.fontFamily`, so every `TextStyle` that names no family
  /// inherits it — which is the ~800 inline styles carrying body text, and
  /// the right answer for all of them.
  ///
  /// [displayFontFamily] has to be named, because a hand-typed `TextStyle`
  /// has no way to know it is a header. It appears on the header tiers below,
  /// on the AppBar title in [Styles], and on the inline styles that draw a
  /// page/sheet/section title or a hero line — grep for it to see the set.
  /// Anything that is not a header must leave the family off: a body style
  /// that names [bodyFontFamily] is saying the same thing twice, and a
  /// number, a price, an avatar initial or a button label set in Syne is
  /// simply wrong.
  ///
  /// Two things a Syne style must not do, both inherited from the Poppins it
  /// replaced and both pinned by `brand_typography_test`:
  ///
  /// * **Ask for a weight above [bold].** The design file stops at 700, and so
  ///   does Syne's usable range — its `wght` axis ends at 800 and there is no
  ///   Black to bundle, so a style asking for one gets the nearest face and,
  ///   on iOS, can get it synthetically emboldened, which reads as smeared
  ///   rather than heavier.
  /// * **Carry negative `letterSpacing`.** Poppins is a wide, round face and
  ///   its headers were tightened by hand, a tier at a time. Syne is already
  ///   narrow and tightly fitted; the same -0.3 to -0.6 closes its counters
  ///   and is the single thing most likely to make the brand face read as
  ///   "nearly right". Leave tracking off and let the face space itself.
  static const String displayFontFamily = 'Syne';
  static const String bodyFontFamily = 'DM Sans';

  // ── The scale ───────────────────────────────────────────────────────────
  //
  // Figma: typography/12 … typography/24, aliased there as text-xs … text-2xl.
  // Seven steps and no eighth: a size that wants to sit between two of these
  // is a design decision, not a rounding one, and belongs in the file first.

  /// 12 — `text-xs`. Timestamps, pill tags, meta lines.
  static double get xs => 12.sp;

  /// 14 — `text-sm`. The app's body size.
  static double get sm => 14.sp;

  /// 15 — `text-base`. Body with a little more room: form fields, list rows.
  static double get base => 15.sp;

  /// 16 — `text-md`. Page and sheet titles.
  static double get md => 16.sp;

  /// 18 — `text-lg`. Section headlines within a page.
  static double get lg => 18.sp;

  /// 22 — `text-xl`.
  static double get xl => 22.sp;

  /// 24 — `text-2xl`. Hero lines: onboarding, empty states, the splash.
  static double get xxl => 24.sp;

  /// Below the scale, and deliberately outside it: 9 and 11 are unread-count
  /// bubbles and micro tags, drawn inside fixed-size containers that 12 would
  /// overflow. The design file has no token this small because it draws no
  /// text this small. Do not reach for these for anything a reader reads.
  static double get badge => 9.sp;
  static double get tag => 11.sp;

  // ── Weights ─────────────────────────────────────────────────────────────
  //
  // Four, the same four the file has. There is no semibold: what the app used
  // to spell w600 is [medium], and what it spelled w800/w900 is [bold].

  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight bold = FontWeight.w700;

  // ── Line heights ────────────────────────────────────────────────────────
  //
  // Multipliers, as Flutter's `height` takes them. Left unset on the tiers
  // below — Flutter then uses the face's own metrics, which is right for a
  // single line — and named here for the paragraphs that need setting:
  // `AppTypography.body.copyWith(height: AppTypography.normal)`.

  /// 1.3 — headings and anything that wraps to two or three lines.
  static const double tight = 1.3;

  /// 1.5 — running text. Captions, descriptions, message bodies.
  static const double normal = 1.5;

  /// 1.7 — long-form reading: terms, help articles, policy pages.
  static const double loose = 1.7;

  // ── Role tiers ──────────────────────────────────────────────────────────

  /// 9 / medium — unread counts and micro tags. See [badge].
  static TextStyle get micro => TextStyle(
        fontSize: badge,
        fontWeight: medium,
      );

  /// 11 / medium — small labels and pill tags. See [tag].
  static TextStyle get label => TextStyle(
        fontSize: tag,
        fontWeight: medium,
      );

  /// 12 / medium — secondary and meta text: subtitles, hints, timestamps.
  static TextStyle get caption => TextStyle(
        fontSize: xs,
        fontWeight: medium,
      );

  /// 12 / bold — [caption] emphasised, e.g. a small count that has to stand.
  static TextStyle get captionBold => TextStyle(
        fontSize: xs,
        fontWeight: bold,
      );

  /// 14 / regular — default body text.
  static TextStyle get body => TextStyle(
        fontSize: sm,
        fontWeight: regular,
      );

  /// 14 / bold — [body] emphasised.
  static TextStyle get bodyBold => TextStyle(
        fontSize: sm,
        fontWeight: bold,
      );

  /// 15 / regular — body with more room: form fields, list items.
  static TextStyle get bodyLarge => TextStyle(
        fontSize: base,
        fontWeight: regular,
      );

  /// 15 / medium — [bodyLarge] emphasised.
  static TextStyle get bodyLargeBold => TextStyle(
        fontSize: base,
        fontWeight: medium,
      );

  /// 15 / medium — card and list-item subtitles, secondary headings.
  ///
  /// Body type, not Syne: this tier sits inside dense lists next to [caption]
  /// and [body], and a display face at this size reads as noise rather than
  /// hierarchy. A card heading that should be Syne wants [title].
  static TextStyle get subtitle => TextStyle(
        fontSize: base,
        fontWeight: medium,
      );

  // ── Header tiers — Syne ────────────────────────────────────────────────

  /// 16 / bold — page titles, app bar titles, event titles.
  static TextStyle get title => TextStyle(
        fontFamily: displayFontFamily,
        fontSize: md,
        fontWeight: bold,
      );

  /// 18 / bold — section headlines within a page.
  static TextStyle get headline => TextStyle(
        fontFamily: displayFontFamily,
        fontSize: lg,
        fontWeight: bold,
      );

  /// 24 / bold — hero and display text: onboarding, empty states, the splash.
  static TextStyle get display => TextStyle(
        fontFamily: displayFontFamily,
        fontSize: xxl,
        fontWeight: bold,
      );
}
