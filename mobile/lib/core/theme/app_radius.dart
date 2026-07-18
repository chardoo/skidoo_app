/// Named corner-radius scale — the app currently has 20+ distinct
/// `BorderRadius.circular(...)` values with no shared vocabulary. Unscaled
/// (logical) values, same convention as the rest of the codebase: apply
/// `.r` at the call site, e.g.
/// `BorderRadius.circular(AppRadius.md.r)`.
class AppRadius {
  const AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Fully-rounded pill/circle — larger than any realistic element half-height.
  static const double pill = 999;
}
