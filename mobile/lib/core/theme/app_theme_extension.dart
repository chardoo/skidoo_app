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
    required this.publicAmber,
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
    required this.mediaLetterbox,
    required this.mediaBackdropVeil,
  });

  final Color homeBackground;
  final Color cardSurface;
  final Color searchFieldFill;
  final Color searchHintColor;
  final Color searchIconColor;
  final Color accentGold;

  /// Darker partner shade for [accentGold] gradients — was copy-pasted as a
  /// raw literal in ~30 places before being named here.
  final Color accentGoldDark;

  /// The "Public" half of the visibility pill in the Found viewer, sampled
  /// from the design at #FAC775.
  ///
  /// It is *not* a leftover of the old amber [accentGold] (#F5A623, replaced
  /// by green in the Jperg rebrand): the current designs pair it with the new
  /// green in the same export — private photos read green, public ones amber —
  /// so the two are a semantic pair, not two eras of one brand colour.
  final Color publicAmber;

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

  // Media-surround tokens — the area *around* a photo/video shown uncropped
  // (`BoxFit.contain`), not the media itself.
  //
  // These are the reason the Feed / Following feeds used to read as dark in
  // light mode: the media is letterboxed on almost every card, so the surround
  // is most of what's on screen, and it was hard-coded to black. They are
  // deliberately NOT the same thing as [cardOverlayStart]/[cardOverlayEnd],
  // which stay dark in both themes because their job is keeping white text
  // legible over an arbitrary photo.

  /// Flat fill behind contained media — the letterbox/pillarbox bands. Used
  /// where there is no blurred backdrop to fall back on (video).
  final Color mediaLetterbox;

  /// Wash laid over the blurred cover-fit copy of a photo that fills those
  /// bands, so the backdrop doesn't compete with the sharp image on top.
  ///
  /// Light mode needs a heavier veil than dark mode needs a scrim: most photos
  /// are mid-to-dark, so a light wash has more to cover before the surround
  /// reads as belonging to a light page.
  final Color mediaBackdropVeil;

  /// Values sampled directly from the Jperg product designs (folders 1 and 4).
  /// The palette is a **warm neutral** one — R, G and B sit within a few
  /// points of each other with a slight warm bias — not the green-tinted set
  /// this used to carry. That tint was why dark mode read as "dark green"
  /// rather than the near-black the designs show.
  ///
  ///   background #111110 · surface/chip #2C2C2A · text #F7F7F2
  ///   secondary #93928A  · accent #1D9E75
  static const dark = AppThemeExtension(
    homeBackground: Color(0xFF111110),
    cardSurface: Color(0xFF1F1F1D),
    searchFieldFill: Color(0xFF2C2C2A),
    searchHintColor: Color(0xFF93928A),
    searchIconColor: Color(0xFFF7F7F2),
    accentGold: Color(0xFF1D9E75),
    accentGoldDark: Color(0xFF16795B),
    publicAmber: Color(0xFFFAC775),
    likeRed: Color(0xFFFF3B5C),
    errorRed: Color(0xFFFF4757),
    dislikeBlue: Color(0xFF5B6EF5),
    infoBlue: Color(0xFF3B82F6),
    greetingColor: Color(0xFFF7F7F2),
    cardOverlayStart: Color(0x00000000),
    cardOverlayEnd: Color(0xCC000000),
    avatarBackground: Color(0xFF2C2C2A),
    avatarForeground: Color(0xFFF7F7F2),
    logoBadgeBackground: Color(0xFF1D9E75),
    logoTextColor: Color(0xFFF7F7F2),
    searchItemBackground: Color(0xFF2C2C2A),
    searchItemTextColor: Color(0xFFF7F7F2),
    glassFill:   Color(0x1AFFFFFF), // white 10 %
    glassBorder: Color(0x40FFFFFF), // white 25 %
    glassIcon:   Color(0xB3FFFFFF), // white 70 %
    glassHint:   Color(0x8CFFFFFF), // white 55 %
    mediaLetterbox:    Color(0xFF000000),
    mediaBackdropVeil: Color(0x55000000), // black 33 %
  );

  /// The same warm-neutral system inverted, sampled from the light designs in
  /// folder 1: background #F7F7F2 · text #2C2C2A · hairline #E0DDD4 ·
  /// accent #1D9E75 (unchanged across modes).
  static const light = AppThemeExtension(
    homeBackground: Color(0xFFF7F7F2),
    cardSurface: Color(0xFFFFFFFF),
    searchFieldFill: Color(0xFFEFEFE9),
    // The designs use #9E9D97 for placeholder/secondary text, but that is only
    // ~2.4:1 on #F7F7F2 and fails WCAG AA. This keeps the design's warm-grey
    // hue while darkening to ~4.9:1 — same trade-off (and same reason) as the
    // token it replaces.
    searchHintColor: Color(0xFF6B6A63),
    searchIconColor: Color(0xFF2C2C2A),
    accentGold: Color(0xFF1D9E75),
    accentGoldDark: Color(0xFF16795B),
    publicAmber: Color(0xFFFAC775),
    likeRed: Color(0xFFFF3B5C),
    errorRed: Color(0xFFFF4757),
    dislikeBlue: Color(0xFF5B6EF5),
    infoBlue: Color(0xFF3B82F6),
    greetingColor: Color(0xFF2C2C2A),
    cardOverlayStart: Color(0x00000000),
    cardOverlayEnd: Color(0xCC000000),
    avatarBackground: Color(0xFFE0DDD4),
    avatarForeground: Color(0xFF2C2C2A),
    logoBadgeBackground: Color(0xFF1D9E75),
    logoTextColor: Color(0xFF2C2C2A),
    searchItemBackground: Color(0xFFFFFFFF),
    searchItemTextColor: Color(0xFF2C2C2A),
    glassFill:   Color(0x0D000000), // black  5 %
    glassBorder: Color(0x26000000), // black 15 %
    glassIcon:   Color(0xA6000000), // black 65 %
    glassHint:   Color(0x99000000), // black 60 % — AA contrast (was 45 %)
    // The page background itself, so a letterboxed photo sits on the same
    // surface as the rest of the app rather than in a black box.
    mediaLetterbox:    Color(0xFFF7F7F2),
    // 70 %: enough that a dark photo's blur still lands lighter than mid-grey,
    // while leaving a hint of the photo's colour so the bands read as belonging
    // to the image. Tune here — it is the one knob for the whole feed.
    mediaBackdropVeil: Color(0xB3F7F7F2), // background 70 %
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
    Color? publicAmber,
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
    Color? mediaLetterbox,
    Color? mediaBackdropVeil,
  }) {
    return AppThemeExtension(
      homeBackground: homeBackground ?? this.homeBackground,
      cardSurface: cardSurface ?? this.cardSurface,
      searchFieldFill: searchFieldFill ?? this.searchFieldFill,
      searchHintColor: searchHintColor ?? this.searchHintColor,
      searchIconColor: searchIconColor ?? this.searchIconColor,
      accentGold: accentGold ?? this.accentGold,
      accentGoldDark: accentGoldDark ?? this.accentGoldDark,
      publicAmber: publicAmber ?? this.publicAmber,
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
      mediaLetterbox: mediaLetterbox ?? this.mediaLetterbox,
      mediaBackdropVeil: mediaBackdropVeil ?? this.mediaBackdropVeil,
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
      publicAmber: Color.lerp(publicAmber, other.publicAmber, t)!,
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
      mediaLetterbox: Color.lerp(mediaLetterbox, other.mediaLetterbox, t)!,
      mediaBackdropVeil:
          Color.lerp(mediaBackdropVeil, other.mediaBackdropVeil, t)!,
    );
  }
}
