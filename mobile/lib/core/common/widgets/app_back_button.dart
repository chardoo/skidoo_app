import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The app's one back affordance.
///
/// Call sites used to each pick their own glyph — `arrow_back_ios_new_rounded`,
/// `arrow_back_ios_rounded`, `arrow_back_rounded` (a full arrow), and Flutter's
/// [BackButton], which is a *different* icon per platform — at sizes from 14 to
/// 22. Going back therefore looked like a different control on nearly every
/// screen. This is one control, in one place.
///
/// One control, two glyphs: a chevron on iOS and an arrow on Android, because
/// those are the two systems' own back marks and the point of a back button is
/// to be the one the reader already knows. That decision lives in [icon] and
/// nowhere else.
///
/// Screens that can't use the widget itself — a back glyph inside a glass or
/// overlay button, or one sitting in a row next to a label — should still
/// reference [icon] rather than naming an `Icons.` constant of their own.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.onPressed,
    this.result,
    this.color,
    this.size,
    this.tooltip = 'Back',
  });

  /// The canonical glyph, which is not the same glyph on both platforms.
  ///
  /// A chevron on iOS, where back is a chevron everywhere else in the system,
  /// and Material's full arrow on Android, where it is an arrow everywhere else
  /// in the system. The app drew the chevron on both, so on Android every
  /// screen's back control disagreed with the one in the keyboard, the share
  /// sheet and every other app on the device — a small thing that reads as the
  /// app being a port rather than an Android app.
  ///
  /// A getter rather than a `const`, so the ~six call sites that name this
  /// instead of using the widget keep working unchanged. Resolved against
  /// [defaultTargetPlatform], which is what `debugDefaultTargetPlatformOverride`
  /// moves in tests.
  static IconData get icon => _isCupertino
      ? Icons.arrow_back_ios_new_rounded
      : Icons.arrow_back_rounded;

  /// The size the back glyph is drawn at unless a call site overrides it.
  ///
  /// Two numbers for the same reason there are two glyphs. The chevron is tall
  /// and narrow, so 20 draws a mark the size of a 24 dp arrow; the arrow itself
  /// wants Material's own 24, and at 20 it sits visibly small against every
  /// other icon in an app bar.
  static double get defaultSize => _isCupertino ? 20 : 24;

  /// True on Apple platforms, where the system's back affordance is a chevron.
  static bool get _isCupertino =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Defaults to popping the current route — and only if there is something to
  /// go back to.
  ///
  /// Pass this only for a back control that does something other than leave the
  /// screen: a wizard stepping back through its own pages, a page that has to
  /// ask before it closes. **Do not** pass `() => Navigator.of(context).pop()`
  /// — that is the default, minus its safeguard. See [result] for handing a
  /// value back.
  final VoidCallback? onPressed;

  /// What to return to whoever pushed this screen.
  ///
  /// Around 25 screens used to write `onPressed: () => Navigator.pop(result)`,
  /// because returning a value looks like it needs the raw call. It doesn't,
  /// and the raw call is how the app got a black screen: `pop` on the only
  /// route on the stack removes it and leaves the navigator with nothing to
  /// draw. `maybePop` — what this widget has always done by default — declines
  /// instead, and takes a result just the same.
  ///
  /// Whether a screen is the only route is not a property of the screen: the
  /// same page is pushed onto Home most of the time and landed on directly by a
  /// deep link, a notification, or a post-login redirect the rest of it. So
  /// going back worked every time until the once it didn't, which is exactly
  /// how it was reported.
  final Object? result;

  /// Defaults to the theme's foreground. Set it for chevrons over media, which
  /// stay white in either theme.
  final Color? color;

  final double? size;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();

    return IconButton(
      tooltip: tooltip,
      icon: Icon(
        icon,
        color: color ?? ext?.greetingColor,
        size: (size ?? defaultSize).sp,
      ),
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(result),
    );
  }
}
