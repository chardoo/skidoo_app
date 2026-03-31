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
    required this.greetingColor,
    required this.cardOverlayStart,
    required this.cardOverlayEnd,
    required this.avatarBackground,
    required this.avatarForeground,
    required this.logoBadgeBackground,
    required this.logoTextColor,
    required this.searchItemBackground,
    required this.searchItemTextColor,
  });

  final Color homeBackground;
  final Color cardSurface;
  final Color searchFieldFill;
  final Color searchHintColor;
  final Color searchIconColor;
  final Color accentGold;
  final Color greetingColor;
  final Color cardOverlayStart;
  final Color cardOverlayEnd;
  final Color avatarBackground;
  final Color avatarForeground;
  final Color logoBadgeBackground;
  final Color logoTextColor;
  final Color searchItemBackground;
  final Color searchItemTextColor;

  static const dark = AppThemeExtension(
    homeBackground: Color(0xFF0F1117),
    cardSurface: Color(0xFF1A1D24),
    searchFieldFill: Color(0xFF1E2230),
    searchHintColor: Color(0xFF7A7A8A),
    searchIconColor: Color(0xFFFFFFFF),
    accentGold: Color(0xFFF5A623),
    greetingColor: Color(0xFFFFFFFF),
    cardOverlayStart: Color(0x00000000),
    cardOverlayEnd: Color(0xCC000000),
    avatarBackground: Color(0xFF2A2D3A),
    avatarForeground: Color(0xFFFFFFFF),
    logoBadgeBackground: Color(0xFFF5A623),
    logoTextColor: Color(0xFFFFFFFF),
    searchItemBackground: Color(0xFF1E2230),
    searchItemTextColor: Color(0xFFFFFFFF),
  );

  static const light = AppThemeExtension(
    homeBackground: Color(0xFFF2F2F7),
    cardSurface: Color(0xFFFFFFFF),
    searchFieldFill: Color(0xFFE8E8EE),
    searchHintColor: Color(0xFF9A9AAA),
    searchIconColor: Color(0xFF1A1A2E),
    accentGold: Color(0xFFF5A623),
    greetingColor: Color(0xFF1A1A2E),
    cardOverlayStart: Color(0x00000000),
    cardOverlayEnd: Color(0xCC000000),
    avatarBackground: Color(0xFFE0E0E8),
    avatarForeground: Color(0xFF1A1A2E),
    logoBadgeBackground: Color(0xFFF5A623),
    logoTextColor: Color(0xFF1A1A2E),
    searchItemBackground: Color(0xFFFFFFFF),
    searchItemTextColor: Color(0xFF1A1A2E),
  );

  @override
  AppThemeExtension copyWith({
    Color? homeBackground,
    Color? cardSurface,
    Color? searchFieldFill,
    Color? searchHintColor,
    Color? searchIconColor,
    Color? accentGold,
    Color? greetingColor,
    Color? cardOverlayStart,
    Color? cardOverlayEnd,
    Color? avatarBackground,
    Color? avatarForeground,
    Color? logoBadgeBackground,
    Color? logoTextColor,
    Color? searchItemBackground,
    Color? searchItemTextColor,
  }) {
    return AppThemeExtension(
      homeBackground: homeBackground ?? this.homeBackground,
      cardSurface: cardSurface ?? this.cardSurface,
      searchFieldFill: searchFieldFill ?? this.searchFieldFill,
      searchHintColor: searchHintColor ?? this.searchHintColor,
      searchIconColor: searchIconColor ?? this.searchIconColor,
      accentGold: accentGold ?? this.accentGold,
      greetingColor: greetingColor ?? this.greetingColor,
      cardOverlayStart: cardOverlayStart ?? this.cardOverlayStart,
      cardOverlayEnd: cardOverlayEnd ?? this.cardOverlayEnd,
      avatarBackground: avatarBackground ?? this.avatarBackground,
      avatarForeground: avatarForeground ?? this.avatarForeground,
      logoBadgeBackground: logoBadgeBackground ?? this.logoBadgeBackground,
      logoTextColor: logoTextColor ?? this.logoTextColor,
      searchItemBackground: searchItemBackground ?? this.searchItemBackground,
      searchItemTextColor: searchItemTextColor ?? this.searchItemTextColor,
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
      greetingColor: Color.lerp(greetingColor, other.greetingColor, t)!,
      cardOverlayStart: Color.lerp(cardOverlayStart, other.cardOverlayStart, t)!,
      cardOverlayEnd: Color.lerp(cardOverlayEnd, other.cardOverlayEnd, t)!,
      avatarBackground: Color.lerp(avatarBackground, other.avatarBackground, t)!,
      avatarForeground: Color.lerp(avatarForeground, other.avatarForeground, t)!,
      logoBadgeBackground:
          Color.lerp(logoBadgeBackground, other.logoBadgeBackground, t)!,
      logoTextColor: Color.lerp(logoTextColor, other.logoTextColor, t)!,
      searchItemBackground:
          Color.lerp(searchItemBackground, other.searchItemBackground, t)!,
      searchItemTextColor:
          Color.lerp(searchItemTextColor, other.searchItemTextColor, t)!,
    );
  }
}
