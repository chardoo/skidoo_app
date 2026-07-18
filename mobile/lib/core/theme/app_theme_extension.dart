import 'package:flutter/material.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.homeBackground,
    required this.cardSurface,
    required this.searchFieldFill,
    required this.searchHintColor,
    required this.searchIconColor,
    required this.accentGold,
    required this.accentGoldDark,
    required this.likeRed,
    required this.errorRed,
    required this.dislikeBlue,
    required this.infoBlue,
    required this.greetingColor,
    required this.cardOverlayStart,
    required this.cardOverlayEnd,
    required this.avatarBackground,
    required this.avatarForeground,
    required this.logoBadgeBackground,
    required this.logoTextColor,
    required this.searchItemBackground,
    required this.searchItemTextColor,
    required this.glassFill,
    required this.glassBorder,
    required this.glassIcon,
    required this.glassHint,
  });

  final Color homeBackground;
  final Color cardSurface;
  final Color searchFieldFill;
  final Color searchHintColor;
  final Color searchIconColor;
  final Color accentGold;

  /// Darker partner shade for [accentGold] gradients — was copy-pasted as
  /// `Color(0xFF078368)` in ~30 places before being named here.
  final Color accentGoldDark;

  /// "Liked"/heart-active red. Distinct from [errorRed] — same hue family,
  /// different semantic role (positive reaction vs validation error), so
  /// kept as two tokens rather than merged into one.
  final Color likeRed;

  /// Validation/error red — see [likeRed] for why this isn't the same token.
  final Color errorRed;

  /// "Disliked"/thumbs-down-active blue.
  final Color dislikeBlue;

  /// Informational/status badge blue (e.g. "pending review"). Distinct from
  /// [dislikeBlue] — different semantic role.
  final Color infoBlue;

  final Color greetingColor;
  final Color cardOverlayStart;
  final Color cardOverlayEnd;
  final Color avatarBackground;
  final Color avatarForeground;
  final Color logoBadgeBackground;
  final Color logoTextColor;
  final Color searchItemBackground;
  final Color searchItemTextColor;

  // Glass / chrome tokens — used by AppBar, navbar, header, pill tabs.
  // Dark  → white-based (light elements over dark content).
  // Light → black-based (dark elements over light content).
  final Color glassFill;    // subtle tint behind chrome
  final Color glassBorder;  // outline around glass elements
  final Color glassIcon;    // icon / label colour
  final Color glassHint;    // placeholder / secondary text

  static const dark = AppThemeExtension(
    homeBackground: Color(0xFF0E1712),
    cardSurface: Color(0xFF16241D),
    searchFieldFill: Color(0xFF1B2A22),
    searchHintColor: Color(0xFF7A8A85),
    searchIconColor: Color(0xFFFFFFFF),
    accentGold: Color(0xFF0BA98A),
    accentGoldDark: Color(0xFF078368),
    likeRed: Color(0xFFFF3B5C),
    errorRed: Color(0xFFFF4757),
    dislikeBlue: Color(0xFF5B6EF5),
    infoBlue: Color(0xFF3B82F6),
    greetingColor: Color(0xFFFFFFFF),
    cardOverlayStart: Color(0x00000000),
    cardOverlayEnd: Color(0xCC000000),
    avatarBackground: Color(0xFF243830),
    avatarForeground: Color(0xFFFFFFFF),
    logoBadgeBackground: Color(0xFF0BA98A),
    logoTextColor: Color(0xFFFFFFFF),
    searchItemBackground: Color(0xFF1B2A22),
    searchItemTextColor: Color(0xFFFFFFFF),
    glassFill:   Color(0x1AFFFFFF), // white 10 %
    glassBorder: Color(0x40FFFFFF), // white 25 %
    glassIcon:   Color(0xB3FFFFFF), // white 70 %
    glassHint:   Color(0x8CFFFFFF), // white 55 %
  );

  static const light = AppThemeExtension(
    homeBackground: Color(0xFFF2F2F7),
    cardSurface: Color(0xFFFFFFFF),
    searchFieldFill: Color(0xFFE8E8EE),
    // Darkened for WCAG AA: 0xFF9A9AAA was ~2.5:1 on the light background.
    // 0xFF5E5E6B is ~5:1 on white while staying clearly "secondary".
    searchHintColor: Color(0xFF5E5E6B),
    searchIconColor: Color(0xFF1A1A2E),
    accentGold: Color(0xFF0BA98A),
    accentGoldDark: Color(0xFF078368),
    likeRed: Color(0xFFFF3B5C),
    errorRed: Color(0xFFFF4757),
    dislikeBlue: Color(0xFF5B6EF5),
    infoBlue: Color(0xFF3B82F6),
    greetingColor: Color(0xFF1A1A2E),
    cardOverlayStart: Color(0x00000000),
    cardOverlayEnd: Color(0xCC000000),
    avatarBackground: Color(0xFFE0E0E8),
    avatarForeground: Color(0xFF1A1A2E),
    logoBadgeBackground: Color(0xFF0BA98A),
    logoTextColor: Color(0xFF1A1A2E),
    searchItemBackground: Color(0xFFFFFFFF),
    searchItemTextColor: Color(0xFF1A1A2E),
    glassFill:   Color(0x0D000000), // black  5 %
    glassBorder: Color(0x26000000), // black 15 %
    glassIcon:   Color(0xA6000000), // black 65 %
    glassHint:   Color(0x99000000), // black 60 % — AA contrast (was 45 %)
  );

  @override
  AppThemeExtension copyWith({
    Color? homeBackground,
    Color? cardSurface,
    Color? searchFieldFill,
    Color? searchHintColor,
    Color? searchIconColor,
    Color? accentGold,
    Color? accentGoldDark,
    Color? likeRed,
    Color? errorRed,
    Color? dislikeBlue,
    Color? infoBlue,
    Color? greetingColor,
    Color? cardOverlayStart,
    Color? cardOverlayEnd,
    Color? avatarBackground,
    Color? avatarForeground,
    Color? logoBadgeBackground,
    Color? logoTextColor,
    Color? searchItemBackground,
    Color? searchItemTextColor,
    Color? glassFill,
    Color? glassBorder,
    Color? glassIcon,
    Color? glassHint,
  }) {
    return AppThemeExtension(
      homeBackground: homeBackground ?? this.homeBackground,
      cardSurface: cardSurface ?? this.cardSurface,
      searchFieldFill: searchFieldFill ?? this.searchFieldFill,
      searchHintColor: searchHintColor ?? this.searchHintColor,
      searchIconColor: searchIconColor ?? this.searchIconColor,
      accentGold: accentGold ?? this.accentGold,
      accentGoldDark: accentGoldDark ?? this.accentGoldDark,
      likeRed: likeRed ?? this.likeRed,
      errorRed: errorRed ?? this.errorRed,
      dislikeBlue: dislikeBlue ?? this.dislikeBlue,
      infoBlue: infoBlue ?? this.infoBlue,
      greetingColor: greetingColor ?? this.greetingColor,
      cardOverlayStart: cardOverlayStart ?? this.cardOverlayStart,
      cardOverlayEnd: cardOverlayEnd ?? this.cardOverlayEnd,
      avatarBackground: avatarBackground ?? this.avatarBackground,
      avatarForeground: avatarForeground ?? this.avatarForeground,
      logoBadgeBackground: logoBadgeBackground ?? this.logoBadgeBackground,
      logoTextColor: logoTextColor ?? this.logoTextColor,
      searchItemBackground: searchItemBackground ?? this.searchItemBackground,
      searchItemTextColor: searchItemTextColor ?? this.searchItemTextColor,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassIcon: glassIcon ?? this.glassIcon,
      glassHint: glassHint ?? this.glassHint,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      homeBackground: Color.lerp(homeBackground, other.homeBackground, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      searchFieldFill: Color.lerp(searchFieldFill, other.searchFieldFill, t)!,
      searchHintColor: Color.lerp(searchHintColor, other.searchHintColor, t)!,
      searchIconColor: Color.lerp(searchIconColor, other.searchIconColor, t)!,
      accentGold: Color.lerp(accentGold, other.accentGold, t)!,
      accentGoldDark: Color.lerp(accentGoldDark, other.accentGoldDark, t)!,
      likeRed: Color.lerp(likeRed, other.likeRed, t)!,
      errorRed: Color.lerp(errorRed, other.errorRed, t)!,
      dislikeBlue: Color.lerp(dislikeBlue, other.dislikeBlue, t)!,
      infoBlue: Color.lerp(infoBlue, other.infoBlue, t)!,
      greetingColor: Color.lerp(greetingColor, other.greetingColor, t)!,
      cardOverlayStart: Color.lerp(cardOverlayStart, other.cardOverlayStart, t)!,
      cardOverlayEnd: Color.lerp(cardOverlayEnd, other.cardOverlayEnd, t)!,
      avatarBackground: Color.lerp(avatarBackground, other.avatarBackground, t)!,
      avatarForeground: Color.lerp(avatarForeground, other.avatarForeground, t)!,
      logoBadgeBackground: Color.lerp(logoBadgeBackground, other.logoBadgeBackground, t)!,
      logoTextColor: Color.lerp(logoTextColor, other.logoTextColor, t)!,
      searchItemBackground: Color.lerp(searchItemBackground, other.searchItemBackground, t)!,
      searchItemTextColor: Color.lerp(searchItemTextColor, other.searchItemTextColor, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassIcon: Color.lerp(glassIcon, other.glassIcon, t)!,
      glassHint: Color.lerp(glassHint, other.glassHint, t)!,
    );
  }
}
