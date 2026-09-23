import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The app's one back affordance.
///
/// Call sites used to each pick their own glyph — `arrow_back_ios_new_rounded`,
/// `arrow_back_ios_rounded`, `arrow_back_rounded` (a full arrow), and Flutter's
/// [BackButton], which is a *different* icon per platform — at sizes from 14 to
/// 22. Going back therefore looked like a different control on nearly every
/// screen. This is the chevron, at one size, in one place.
///
/// Screens that can't use the widget itself — a back chevron inside a glass or
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

  /// The canonical glyph: a chevron, not a full arrow. The arrow reads as an
  /// Android control on an iPhone, where back is a chevron everywhere else in
  /// the system.
  static const IconData icon = Icons.arrow_back_ios_new_rounded;

  /// The size every back chevron is drawn at unless a call site overrides it.
  ///
  /// Smaller than the arrow this replaced (22): the chevron is a tall, narrow
  /// glyph, so the same nominal size draws a visibly bigger mark.
  static const double defaultSize = 20;

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
