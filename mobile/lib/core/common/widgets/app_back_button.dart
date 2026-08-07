import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The app's one back affordance.
///
/// Call sites used to each pick their own glyph — `arrow_back_ios_new_rounded`
/// (a bare chevron), `arrow_back_ios_rounded`, `arrow_back_rounded`, and
/// Flutter's [BackButton], which is a *different* icon per platform — at sizes
/// from 14 to 22. Going back therefore looked like a different control on
/// nearly every screen. This is the arrow, at one size, in one place.
///
/// Screens that can't use the widget itself — a back arrow inside a glass or
/// overlay button, or one sitting in a row next to a label — should still
/// reference [icon] rather than naming an `Icons.` constant of their own.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.size,
    this.tooltip = 'Back',
  });

  /// The canonical glyph: a full arrow, not a bare chevron.
  static const IconData icon = Icons.arrow_back_rounded;

  /// The size every back arrow is drawn at unless a call site overrides it.
  static const double defaultSize = 22;

  /// Defaults to popping the current route.
  final VoidCallback? onPressed;

  /// Defaults to the theme's foreground. Set it for arrows over media, which
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
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}
