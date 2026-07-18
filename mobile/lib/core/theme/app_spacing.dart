/// Named spacing scale — the app currently has 20+ distinct hand-picked
/// gap/padding values with no shared vocabulary. These are unscaled
/// (logical) values, same convention as the rest of the codebase: apply
/// `.w`/`.h`/`.r` at the call site via flutter_screenutil, e.g.
/// `SizedBox(height: AppSpacing.md.h)` or
/// `EdgeInsets.symmetric(horizontal: AppSpacing.lg.w)`.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
}
